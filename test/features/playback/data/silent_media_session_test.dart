import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/data/silent_media_session.dart';
import 'package:orpheus/features/playback/domain/media_session.dart';

/// The media session of a desktop, which has none to publish to.
///
/// The controller above it runs unchanged on every target, so this has to
/// answer everything it is asked and never send a command back.
void main() {
  const nowPlaying = NowPlaying(id: '/music/a.flac', title: 'A');

  test(
    'GivenADesktopSession_WhenATrackIsShownAndHidden_ThenNoCommandIsEverSent',
    () async {
      final session = SilentMediaSession();
      final commands = <MediaSessionCommand>[];
      final subscription = session.commands.listen(commands.add);
      addTearDown(subscription.cancel);

      await session.show(nowPlaying);
      await session.hide();
      await pumpEventQueue();

      expect(commands, isEmpty);
      await session.dispose();
    },
  );

  test(
    'GivenADesktopSession_WhenItIsListenedToTwice_ThenBothListenersAreAccepted',
    () async {
      final session = SilentMediaSession();

      final first = session.commands.listen((_) {});
      final second = session.commands.listen((_) {});

      await first.cancel();
      await second.cancel();
      await session.dispose();
    },
  );

  test(
    'GivenADesktopSession_WhenItIsDisposed_ThenItsCommandsAreDone',
    () async {
      final session = SilentMediaSession();
      final done = Completer<void>();
      session.commands.listen((_) {}, onDone: done.complete);

      await session.dispose();

      await expectLater(done.future, completes);
    },
  );
}
