import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/shell/presentation/async_state_view.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';
import 'package:orpheus/features/shell/presentation/shell_screen.dart';
import 'package:orpheus/features/stats/presentation/music_stats_screen.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The screen that says what the owner listens to.
void main() {
  final library = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: 'ok2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: 'blue', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue'),
  ];

  /// A harness whose history already holds [plays].
  Harness harnessWith(Map<String, int> plays) {
    final harness = Harness(library: library);
    harness.plays.history = PlayHistory(
      tracks: {
        for (final played in plays.entries)
          played.key: TrackPlays(
            path: played.key,
            plays: played.value,
            lastPlayedAt: DateTime.utc(2026),
          ),
      },
    );

    return harness;
  }

  testWidgets(
    'GivenTracksHaveBeenPlayed_WhenTheScreenIsShown_ThenTheTotalsAndTheRankingsAreOnIt',
    (tester) async {
      final harness = harnessWith({
        library[0].file.path: 5,
        library[2].file.path: 2,
      });

      await tester.pumpHarness(harness, const MusicStatsScreen());

      expect(find.text('7'), findsOneWidget); // plays
      expect(find.text('2'), findsWidgets); // distinct tracks
      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('Radiohead'), findsOneWidget);
      expect(find.text('OK Computer'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNothingHasBeenPlayed_WhenTheScreenIsShown_ThenItSaysWhatCounts',
    (tester) async {
      // An owner who has been playing music and sees a blank screen is owed
      // the rule, not the absence.
      final harness = harnessWith({});

      await tester.pumpHarness(harness, const MusicStatsScreen());

      expect(find.text('Nothing counted yet'), findsOneWidget);
      expect(find.textContaining('four minutes'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARankingWithNothingInIt_WhenTheScreenIsShown_ThenItsHeadingIsStillDrawn',
    (tester) async {
      // A heading with nothing under it says the ranking exists and has
      // nothing in it; dropping it says the application forgot about genres.
      final harness = harnessWith({library[0].file.path: 1});

      await tester.pumpHarness(harness, const MusicStatsScreen());

      expect(find.text('Most played genres'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlayedTrackWithNoTags_WhenTheScreenIsShown_ThenItIsNamedByItsFileAndExplained',
    (tester) async {
      final harness = Harness(library: [...library, entry(id: 'nothing')]);
      harness.plays.history = PlayHistory(
        tracks: {
          '/library/zzz-nothing.flac': TrackPlays(
            path: '/library/zzz-nothing.flac',
            plays: 3,
            lastPlayedAt: DateTime.utc(2026),
          ),
        },
      );

      await tester.pumpHarness(harness, const MusicStatsScreen());

      expect(find.text('zzz-nothing.flac'), findsOneWidget);
      expect(find.textContaining('no artist, record or genre tag'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheStatisticsAreShown_WhenReadAgainIsPressed_ThenTheyAreReadAfresh',
    (tester) async {
      final harness = harnessWith({library[0].file.path: 1});
      await tester.pumpHarness(harness, const MusicStatsScreen());
      expect(find.text('1'), findsWidgets);

      // A play landed while the screen was open; the screen does not follow
      // the music, so it takes pressing the button to see it.
      await harness.read(playRecorderProvider).record(library[0].file.path);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
    },
  );

  testWidgets(
    'GivenTheLibraryCannotBeRead_WhenTheScreenIsShown_ThenTheStatisticsAreStillCounted',
    (tester) async {
      // Statistics do not fail because the library did: every play still
      // happened, and what is lost is only the names to rank them by.
      final harness = harnessWith({'/library/zzz-gone.flac': 4});
      harness.catalogs.failOnRead = true;

      await tester.pumpHarness(harness, const MusicStatsScreen());

      expect(find.byType(ShellFailureView), findsNothing);
      expect(find.text('4'), findsWidgets);
      expect(find.text('zzz-gone.flac'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheShellIsOnScreen_WhenTheStatisticsButtonIsPressed_ThenTheScreenOpens',
    (tester) async {
      // The app bar is the only way in, so nothing else guards this wiring.
      final harness = harnessWith({library[0].file.path: 1});

      await tester.pumpHarness(harness, const ShellScreen());
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(MusicStatsScreen), findsOneWidget);
      expect(find.text('What you listen to'), findsOneWidget);
    },
  );
}
