import 'dart:async';

import 'package:orpheus/features/playback/domain/media_session.dart';

/// A [MediaSession] that records what it was shown and can press its own
/// buttons.
///
/// The platform session is a foreground service and a notification, neither of
/// which exists in a test process — which is the whole reason `MediaSession` is
/// an interface. With this in its place, "the lock screen would be showing
/// this" and "the owner pressed next on their headphones" are both assertions
/// a test can make.
class FakeMediaSession implements MediaSession {
  final StreamController<MediaSessionCommand> _commands =
      StreamController<MediaSessionCommand>.broadcast();

  /// Everything published, in order.
  final List<NowPlaying> shown = [];

  /// How many times the session was taken down.
  int hides = 0;

  /// Whether [dispose] was called.
  bool disposed = false;

  /// What is on screen now, or `null` where the session has been taken down.
  ///
  /// Not the last entry in [shown]: a session that showed a track and was then
  /// hidden is showing nothing, and a fake that could not tell those apart
  /// would let a notification left up behind a stopped player pass as correct.
  NowPlaying? onScreen;

  @override
  Stream<MediaSessionCommand> get commands => _commands.stream;

  /// Sends [command] as though it had been pressed outside the application.
  void press(MediaSessionCommand command) => _commands.add(command);

  @override
  Future<void> show(NowPlaying nowPlaying) async {
    shown.add(nowPlaying);
    onScreen = nowPlaying;
  }

  @override
  Future<void> hide() async {
    hides++;
    onScreen = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _commands.close();
  }
}
