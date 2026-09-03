import 'dart:async';

import '../domain/media_session.dart';

/// [MediaSession] on a platform that has none.
///
/// Windows and Linux. Neither has a notification a music player publishes to
/// and neither takes the audio output away for a phone call, so there is
/// nothing to show and nothing to send back — which is the whole of this
/// class, and is why the player above it needs no platform check.
///
/// The empty command stream is deliberate rather than incidental: a listener
/// on it is valid and simply never fires, so the controller that routes
/// commands runs unchanged on all three targets.
class SilentMediaSession implements MediaSession {
  /// Creates the session.
  SilentMediaSession();

  final StreamController<MediaSessionCommand> _commands =
      StreamController<MediaSessionCommand>.broadcast();

  @override
  Stream<MediaSessionCommand> get commands => _commands.stream;

  @override
  Future<void> show(NowPlaying nowPlaying) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> dispose() async {
    await _commands.close();
  }
}
