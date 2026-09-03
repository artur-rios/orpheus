import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_catalog.dart';
import '../domain/media_session.dart';
import '../domain/playback_queue.dart';
import 'audio_playback_controller.dart';

/// The words the session shows for a file whose tags name nothing.
///
/// Passed in rather than written here, for the reason every other name in the
/// application layer is: this is code with no `AppLocalizations` to reach, and
/// three words written into it would be three words in one language for every
/// owner. The shell supplies them and keeps them current when the language
/// changes — see `MediaSessionNamesScope`.
class MediaSessionNames {
  /// Creates the words.
  const MediaSessionNames({
    required this.unknownTitle,
    required this.unknownArtist,
    required this.unknownAlbum,
  });

  /// What an untitled track is called.
  final String unknownTitle;

  /// What a track with no performer is called.
  final String unknownArtist;

  /// What a track on no named record is called.
  final String unknownAlbum;

  @override
  bool operator ==(Object other) =>
      other is MediaSessionNames &&
      unknownTitle == other.unknownTitle &&
      unknownArtist == other.unknownArtist &&
      unknownAlbum == other.unknownAlbum;

  @override
  int get hashCode => Object.hash(unknownTitle, unknownArtist, unknownAlbum);
}

/// Keeps the platform's media session showing what the player is doing, and
/// hands back what was pressed on it.
///
/// A view of the player, in the same sense the playback bar is: it watches the
/// same state and it calls the same methods, and it decides nothing on its own.
/// It is not a widget, and that is the point — on Android the notification
/// outlives the moment the owner switches away from the application, and
/// anything driving it from inside the widget tree would be publishing from a
/// view the system is entitled to take down.
///
/// Its state is the last thing published, which is what makes what a lock
/// screen would be showing an assertion a test can make.
class MediaSessionController extends Notifier<NowPlaying?> {
  MediaSession get _session => ref.read(mediaSessionProvider);

  /// Which run of [_publish] is the current one.
  ///
  /// The sleeve is read from disk part-way through, so two publishes overlap
  /// whenever a track changes while the previous one's picture is still being
  /// located — and the older run coming back last would leave the notification
  /// showing the track before this one.
  int _generation = 0;

  MediaSessionNames? _names;

  /// The last sleeve located, by the cover it was located for.
  ///
  /// One lookup per record rather than one per position tick: every track on a
  /// record shares a cover id, and the player publishes several times a second
  /// while it runs.
  String? _artCoverId;
  String? _artPath;

  @override
  NowPlaying? build() {
    final commands = _session.commands.listen(
      (command) => unawaited(_route(command)),
    );
    ref.onDispose(() => unawaited(commands.cancel()));

    // The player is the source of everything shown. The library is watched too
    // because it is what a track is *named* from, and it loads after the first
    // frame — a track played before it arrives would otherwise sit in the
    // notification under its Unknown words for the rest of the session.
    ref.listen(audioPlaybackControllerProvider, (_, next) {
      unawaited(_publish(next));
    });
    ref.listen(musicLibraryControllerProvider, (_, _) {
      unawaited(_publish(ref.read(audioPlaybackControllerProvider)));
    });

    return null;
  }

  /// Takes the words the session falls back to, and republishes under them.
  ///
  /// Called whenever the resolved language changes, which includes the first
  /// time it resolves at all: nothing is published before this arrives,
  /// because a notification is a sentence and there is no sentence yet.
  void remember(MediaSessionNames names) {
    if (_names == names) return;

    _names = names;
    unawaited(_publish(ref.read(audioPlaybackControllerProvider)));
  }

  /// Shows [playback], or takes the session down where there is nothing to
  /// show.
  Future<void> _publish(AudioPlaybackState playback) async {
    final generation = ++_generation;
    final names = _names;
    final file = playback.current;
    final shows = switch (playback.stage) {
      // A track is open, or is being opened — both of which are something to
      // put on a lock screen, and the second of which is what makes the
      // notification appear as playback starts rather than a moment later.
      AudioStage.starting || AudioStage.playing => true,
      // Nothing is queued, nothing could be played, or the owner has been
      // asked where to resume from and has not answered. None of the three is
      // a track playing.
      AudioStage.idle ||
      AudioStage.allFailed ||
      AudioStage.offeringResume => false,
    };

    if (names == null || file == null || !shows) {
      if (state == null) return;

      state = null;
      await _session.hide();

      return;
    }

    final library =
        ref.read(musicLibraryControllerProvider).value ?? MusicCatalog.empty;
    final entry = library.entryFor(file);
    final art = await _artFor(entry.metadata.coverId);
    if (generation != _generation) return;

    final nowPlaying = NowPlaying(
      id: file.path,
      title: entry.title ?? names.unknownTitle,
      artist: entry.artist ?? names.unknownArtist,
      album: entry.album ?? names.unknownAlbum,
      // What the engine measured, and the tag only until it has: the tag is
      // what a listing shows before anything is opened, and the engine is the
      // one that has actually read the file.
      duration: playback.status.duration ?? entry.duration,
      artPath: art,
      position: playback.status.position,
      isPlaying: playback.isPlaying,
      // Repeat is part of the answer: at the end of a queue set to repeat, the
      // next button goes back to the top, and a button drawn dead there would
      // be lying about what pressing it does.
      hasNext:
          playback.queue.hasNext ||
          (playback.repeat != QueueRepeat.off && !playback.queue.isEmpty),
      // Always, while something is playing. Pressing back near the start of a
      // track steps to the one before it and pressing it later restarts this
      // one, so there is no point in the queue where the button does nothing.
      hasPrevious: true,
    );

    if (nowPlaying == state) return;

    state = nowPlaying;
    await _session.show(nowPlaying);
  }

  /// The sleeve stored under [coverId], as a file the platform can load.
  Future<String?> _artFor(String? coverId) async {
    if (coverId == null) {
      _artCoverId = null;
      _artPath = null;

      return null;
    }

    if (coverId == _artCoverId) return _artPath;

    _artCoverId = coverId;
    _artPath = await ref.read(coverStoreProvider).locationOf(coverId);

    return _artPath;
  }

  /// Does what was pressed.
  ///
  /// Every arm calls the same method the equivalent button on the playback bar
  /// calls. Nothing is decided here — a command that arrives when it makes no
  /// sense is one the player already ignores, which is what keeps this a
  /// routing table rather than a second player.
  Future<void> _route(MediaSessionCommand command) async {
    final player = ref.read(audioPlaybackControllerProvider.notifier);

    switch (command) {
      // Resume and pause are the same call, guarded on which way it would go.
      // Audio focus sends a pause for a call arriving whether or not anything
      // was playing, and an unguarded toggle would answer that by starting the
      // music up into the middle of it.
      case ResumeAsked():
        if (!ref.read(audioPlaybackControllerProvider).isPlaying) {
          await player.togglePlaying();
        }
      case PauseAsked():
        if (ref.read(audioPlaybackControllerProvider).isPlaying) {
          await player.togglePlaying();
        }
      case NextAsked():
        await player.next();
      case PreviousAsked():
        await player.previous();
      case StopAsked():
        await player.stop();
      case SeekAsked(:final position):
        await player.seekTo(position);
    }
  }
}
