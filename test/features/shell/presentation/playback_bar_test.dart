import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:orpheus/features/playback/domain/playback_position_store.dart';
import 'package:orpheus/features/shell/presentation/playback_bar.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The bar that holds the bottom of the shell all session.
void main() {
  final library = [
    entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer', track: 1),
    entry(id: '2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer', track: 2),
  ];

  Widget bar() => const Scaffold(body: Column(children: [PlaybackBar()]));

  testWidgets(
    'GivenNothingHasBeenPlayed_WhenTheBarIsShown_ThenItSaysSoRatherThanBeingAbsent',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, bar());

      expect(find.text('Nothing is playing'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARecordIsPlaying_WhenTheBarIsShown_ThenItNamesTheTrackAndTheRecord',
    (tester) async {
      final harness = Harness(library: library);
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);

      await tester.pumpHarness(harness, bar());

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('OK Computer'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATrackIsPlaying_WhenTheEngineReportsALength_ThenTheBarShowsWhereItHasGot',
    (tester) async {
      final harness = Harness(library: library);
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);
      await tester.pumpHarness(harness, bar());

      harness.player.report(
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(seconds: 30),
          duration: Duration(minutes: 4, seconds: 44),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('00:30 / 04:44'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheEngineHasNotWorkedOutTheLength_WhenTheBarIsShown_ThenNoTimesAreShownAtAll',
    (tester) async {
      // "00:00 / 00:00" beside a bar is noise, and a track whose length the
      // engine has not worked out has nothing to divide by.
      final harness = Harness(library: library);
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);

      await tester.pumpHarness(harness, bar());

      expect(find.textContaining('/'), findsNothing);
    },
  );

  testWidgets(
    'GivenATrackWasSkipped_WhenTheBarIsShown_ThenItIsNamedAboveWhatIsPlayingNow',
    (tester) async {
      // The queue has already moved on, and the owner is listening to the next
      // one — so the notice sits above the bar rather than replacing it.
      final harness = Harness(
        library: library,
        missingTracks: {library.first.file.path},
      );
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);

      await tester.pumpHarness(harness, bar());

      expect(find.textContaining('Skipped'), findsOneWidget);
      expect(find.text('Karma Police'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheSkipNoticeIsShown_WhenItIsDismissed_ThenItGoesAway',
    (tester) async {
      final harness = Harness(
        library: library,
        missingTracks: {library.first.file.path},
      );
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);
      await tester.pumpHarness(harness, bar());

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Skipped'), findsNothing);
    },
  );

  testWidgets(
    'GivenATrackWithAStoredPosition_WhenItIsAskedFor_ThenTheBarAsksBeforeAnythingPlays',
    (tester) async {
      // Asked in the bar rather than over the screen: the owner is somewhere
      // else in the application, and a modal would interrupt it.
      final harness = Harness(library: library);
      await harness.library();
      await harness.read(playbackPositionsProvider).record(
        PlaybackPosition(
          path: library.first.file.path,
          position: const Duration(minutes: 2),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playTrack(library.first.file);

      await tester.pumpHarness(harness, bar());

      expect(find.textContaining('Continue from 02:00'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPhoneSizedWindow_WhenTheBarIsShown_ThenOnlyTheControlsAThumbNeedsAreOnIt',
    (tester) async {
      final harness = Harness(library: library);
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);

      await tester.pumpHarness(harness, bar(), window: phoneWindow);

      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      // Stop, previous and the open-the-player chevron are the desktop bar's;
      // on a phone the full player is one tap on the sleeve away.
      expect(find.byIcon(Icons.stop), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    },
  );
}
