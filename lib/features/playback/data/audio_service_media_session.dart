import 'dart:async';

import 'package:audio_service/audio_service.dart' as service;
import 'package:audio_session/audio_session.dart' as focus;
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/media_session.dart';

/// [MediaSession] over `audio_service`, which is what keeps playback alive on
/// Android once the application is no longer on screen.
///
/// Everything Android-shaped stops here. The service this publishes to is a
/// foreground service: the notification it posts is the thing that stops the
/// system from reclaiming the process the moment the owner switches away, and
/// so the notification is not decoration around background playback — it *is*
/// the background playback, as far as Android is concerned. That is why
/// [hide] is the only way playback ends, and why a session that failed to
/// start is reported rather than swallowed.
///
/// Two kinds of thing arrive back through [commands]: the transport buttons,
/// which the owner pressed, and audio focus, which the owner did not — a phone
/// call arriving, or headphones pulled out of the socket. Both are the same
/// ask from the player's side ("pause"), which is why they share one stream
/// rather than the player learning the difference.
class AudioServiceMediaSession implements MediaSession {
  /// Wraps [handler], which [start] built.
  AudioServiceMediaSession._(this._handler);

  static final Logger _log = Logger('playback');

  /// Starts the platform service and answers the session over it.
  ///
  /// Asynchronous and called once, from `main`, because that is what the
  /// platform requires: the service is bound to the process before the first
  /// frame, and a second one would be a second thing holding the audio output.
  static Future<AudioServiceMediaSession> start() async {
    final handler = await service.AudioService.init(
      builder: _TransportHandler.new,
      config: const service.AudioServiceConfig(
        androidNotificationChannelId: 'io.github.artur_rios.orpheus.playback',
        androidNotificationChannelName: 'Playback',
        // The channel is not the place for a description the owner reads as an
        // advertisement: this is the only notification this application ever
        // posts, and it says what is playing.
        androidNotificationChannelDescription: 'What Orpheus is playing',
        // Ongoing while playing, and dismissible once paused. Together these
        // two are what "a music player's notification" means: it cannot be
        // swiped away mid-song by accident, and it does not become a permanent
        // fixture after the owner has stopped listening.
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    final session = AudioServiceMediaSession._(handler);
    await session._followAudioFocus();

    return session;
  }

  final _TransportHandler _handler;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Whether the owner has been asked to allow the notification yet.
  ///
  /// Asked for at the moment there is something to show, in the same way read
  /// access is asked for once a folder has been registered: a permission
  /// dialog on a launch that nobody has pressed play in is a question about
  /// nothing.
  bool _askedToNotify = false;

  /// What was published last, so the track is re-announced only when it
  /// changes — see `NowPlaying.sameTrackAs`.
  NowPlaying? _shown;

  @override
  Stream<MediaSessionCommand> get commands => _handler.commands;

  @override
  Future<void> show(NowPlaying nowPlaying) async {
    await _askToNotify();

    final previous = _shown;
    _shown = nowPlaying;

    if (previous == null || !previous.sameTrackAs(nowPlaying)) {
      _handler.mediaItem.add(_itemOf(nowPlaying));
    }

    _handler.playbackState.add(_stateOf(nowPlaying));
  }

  @override
  Future<void> hide() async {
    _shown = null;
    _handler.mediaItem.add(null);
    _handler.playbackState.add(
      service.PlaybackState(
        processingState: service.AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _handler.dispose();
  }

  /// Asks Android for permission to post the notification, once.
  ///
  /// A refusal is not fatal and is not retried: playback still runs, and the
  /// owner has said they do not want to see it. Android is the only host this
  /// class is ever constructed on, so there is no platform check here.
  Future<void> _askToNotify() async {
    if (_askedToNotify) return;
    _askedToNotify = true;

    try {
      final decision = await Permission.notification.request();
      if (!decision.isGranted) {
        _log.info('the playback notification was refused; playback continues');
      }
    } on Object catch (error) {
      // A permission that cannot be asked for is a permission that is not
      // there to ask for — every release before Android 13 — and playback has
      // nothing to do about it either way.
      _log.fine('the notification permission could not be asked for', error);
    }
  }

  /// Follows audio focus, and reports losing it as a pause.
  ///
  /// Two events, and they mean different things. An interruption is the system
  /// handing the output to something else — a call, an alarm, another player —
  /// and a *temporary* one hands it back, which is the one case anything here
  /// resumes by itself. Becoming noisy is the headphones leaving the socket,
  /// and it never resumes: the owner took them out, and a record starting up
  /// out of the speaker is exactly what they were avoiding.
  Future<void> _followAudioFocus() async {
    final session = await focus.AudioSession.instance;
    await session.configure(const focus.AudioSessionConfiguration.music());

    _subscriptions.addAll([
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _handler.ask(const PauseAsked());

          return;
        }

        // Only where the system says the output is ours again. A permanent
        // loss ends with `shouldResume` false, and starting up again there
        // would be this application talking over whatever took the output.
        if (event.type == focus.AudioInterruptionType.pause) {
          _handler.ask(const ResumeAsked());
        }
      }),
      session.becomingNoisyEventStream.listen((_) {
        _handler.ask(const PauseAsked());
      }),
    ]);
  }

  /// [nowPlaying] as the platform's description of a track.
  service.MediaItem _itemOf(NowPlaying nowPlaying) => service.MediaItem(
    id: nowPlaying.id,
    title: nowPlaying.title,
    artist: nowPlaying.artist,
    album: nowPlaying.album,
    duration: nowPlaying.duration,
    // A file URI, which the platform loads and scales itself. There is no
    // network here and there never is: the only pictures this application has
    // are the ones the scan pulled out of the owner's own files.
    artUri: nowPlaying.artPath == null
        ? null
        : Uri.file(nowPlaying.artPath!),
  );

  /// [nowPlaying] as the platform's description of what playback is doing.
  service.PlaybackState _stateOf(NowPlaying nowPlaying) =>
      service.PlaybackState(
        controls: [
          service.MediaControl.skipToPrevious,
          if (nowPlaying.isPlaying)
            service.MediaControl.pause
          else
            service.MediaControl.play,
          service.MediaControl.skipToNext,
          service.MediaControl.stop,
        ],
        // Which three of the four the collapsed notification shows. Previous,
        // play/pause and next: the buttons a person reaches for without
        // looking. Stop stays in the expanded one.
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {service.MediaAction.seek},
        processingState: service.AudioProcessingState.ready,
        playing: nowPlaying.isPlaying,
        updatePosition: nowPlaying.position,
        bufferedPosition: nowPlaying.position,
      );
}

/// What the platform talks to.
///
/// `audio_service` calls these methods when a button is pressed on the
/// notification, on the lock screen, on a headset or on a steering wheel. Every
/// one of them turns straight into a command and decides nothing: the player is
/// the only thing that knows whether there is a next track, and a handler that
/// answered these itself would be a second player.
class _TransportHandler extends service.BaseAudioHandler {
  final StreamController<MediaSessionCommand> _commands =
      StreamController<MediaSessionCommand>.broadcast();

  /// What was pressed.
  Stream<MediaSessionCommand> get commands => _commands.stream;

  /// Sends [command] on, from wherever it arrived.
  void ask(MediaSessionCommand command) {
    if (!_commands.isClosed) _commands.add(command);
  }

  @override
  Future<void> play() async => ask(const ResumeAsked());

  @override
  Future<void> pause() async => ask(const PauseAsked());

  @override
  Future<void> skipToNext() async => ask(const NextAsked());

  @override
  Future<void> skipToPrevious() async => ask(const PreviousAsked());

  @override
  Future<void> stop() async => ask(const StopAsked());

  @override
  Future<void> seek(Duration position) async => ask(SeekAsked(position));

  /// Closes the command stream.
  Future<void> dispose() => _commands.close();
}
