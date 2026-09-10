import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

import '../domain/media_player.dart';

/// [MediaPlayer] over media_kit.
///
/// Everything media_kit-shaped stops here. Above this line the application
/// knows about a position, a duration, and whether the file could be decoded —
/// which is why the flows are testable without libmpv, and why the same
/// controller drives playback on Windows, on Linux and on Android.
class MediaKitPlayer implements MediaPlayer {
  /// Wraps a media_kit player.
  MediaKitPlayer([mk.Player? player]) : _player = player ?? _createPlayer() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        _update(_status.copyWith(isPlaying: playing));
      }),
      _player.stream.position.listen((position) {
        _update(_status.copyWith(position: position));
      }),
      _player.stream.duration.listen((duration) {
        // Zero is media_kit's "not known yet", and reporting it as a duration
        // would make a seek bar that jumps when the real one arrives.
        _update(
          _status.copyWith(
            duration: duration == Duration.zero ? null : duration,
          ),
        );
      }),
      // Announced once, and not kept. `hasEnded` says "this track just
      // finished", and every other listener here re-emits `_status` — so
      // latching it would mean every position tick after the end carried it
      // too. The playback controller advances its queue on that flag, and a
      // second carrier arriving while it was still opening the next track
      // would advance it twice and the queue would jump a track.
      _player.stream.completed.listen((completed) {
        if (completed) _announce(_status.copyWith(hasEnded: true));
      }),
      // media_kit reports a decode failure on its error stream rather than by
      // throwing from `open`, which is why an unplayable file is a status here
      // rather than an exception.
      _player.stream.error.listen((_) {
        // Once per file, whatever mpv has to say about it. That stream is not
        // one error per unplayable file: a single bad open can write several
        // lines, and so can an output device taken away underneath a file that
        // is perfectly decodable. Above this line each one costs a track — the
        // queue skips the file it is on and opens the next — so a handful of
        // lines about one file used to walk a shuffled library several tracks
        // forward, and a burst of them could walk it to the end and leave the
        // player with nothing queued and nothing playing.
        if (_failedThisFile) return;
        _failedThisFile = true;

        // Not playing any more is state; failing to decode is an event, and is
        // announced rather than kept for the reason `hasEnded` is.
        _update(_status.copyWith(isPlaying: false));
        _announce(_status.copyWith(failedToDecode: true));
      }),
    ]);
  }

  /// Builds the real engine, resolving libmpv first.
  ///
  /// media_kit throws the moment a player is constructed if its native library
  /// has not been located, so the resolution belongs with the construction:
  /// the player is built lazily by its provider, and a bootstrap step in
  /// `main` would be a rule about ordering that the first `ref.read` is free to
  /// break. `ensureInitialized` returns immediately once it has run.
  static mk.Player _createPlayer() {
    mk.MediaKit.ensureInitialized();

    return mk.Player();
  }

  final mk.Player _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<PlaybackStatus> _statuses =
      StreamController<PlaybackStatus>.broadcast();

  PlaybackStatus _status = const PlaybackStatus();
  bool _disposed = false;

  /// Whether the file now open has already been reported as undecodable.
  ///
  /// Cleared by [open] and by [stop], because it is a fact about one file and
  /// nothing else.
  bool _failedThisFile = false;

  @override
  Stream<PlaybackStatus> get status => _statuses.stream;

  @override
  PlaybackStatus get currentStatus => _status;

  @override
  Future<void> open(String path, {Duration startAt = Duration.zero}) async {
    // A fresh status per file: the previous file's duration and its decode
    // failure say nothing about this one.
    _failedThisFile = false;
    _update(const PlaybackStatus(isPlaying: true));

    await _player.open(mk.Media(path));
    if (startAt > Duration.zero) await _player.seek(startAt);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    _failedThisFile = false;
    await _player.stop();
    _update(const PlaybackStatus());
  }

  @override
  Future<void> setVolume(double volume) =>
      // media_kit takes a percentage; the application works in the 0-to-1 the
      // slider and the settings store both use.
      _player.setVolume(volume.clamp(0.0, 1.0) * 100);

  @override
  Future<void> dispose() async {
    // Answered once, because the shutdown path has two callers by design: it
    // releases the engine by hand and waits for it — media_kit's own dispose
    // stops playback, which is what gives the output device back — and the
    // container it was built by then releases it again on its way down.
    // media_kit throws an `AssertionError` on a second dispose, so the second
    // caller is answered here rather than there.
    if (_disposed) return;
    _disposed = true;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _statuses.close();
    await _player.dispose();
  }

  /// Records [status] as the engine's condition, and sends it.
  void _update(PlaybackStatus status) {
    _status = status;
    _announce(status);
  }

  /// Sends [status] to whoever is listening.
  ///
  /// Called directly — rather than through [_update] — for the flags that
  /// describe a moment rather than a condition, so `_status` is left as it was
  /// and the next ordinary update does not carry them along.
  void _announce(PlaybackStatus status) {
    if (!_statuses.isClosed) _statuses.add(status);
  }
}
