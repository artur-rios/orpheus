import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/test_container.dart';

/// The play history as it changes, for whatever reacts to the owner listening.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);

  test(
    'GivenAStoredHistory_WhenItIsWatched_ThenItIsWhatTheStoreHolds',
    () async {
      final harness = Harness(now: now);
      harness.plays.history = PlayHistory(
        tracks: {
          '/library/a.flac': TrackPlays(
            path: '/library/a.flac',
            plays: 4,
            lastPlayedAt: DateTime.utc(2026, 10, 1),
          ),
        },
      );

      final history = await harness.read(playHistoryProvider.future);

      expect(history.tracks['/library/a.flac']!.plays, 4);
    },
  );

  test('GivenTheHistoryIsWatched_WhenAPlayIsRecorded_ThenItUpdatesWithTheDatedPlay', () async {
    final harness = Harness(now: now);
    harness.container.listen(playHistoryProvider, (_, _) {});
    await harness.read(playHistoryProvider.future);

    await harness.read(playRecorderProvider).record('/library/a.flac');
    await pumpEventQueue();

    final history = harness.read(playHistoryProvider).value!;
    expect(history.tracks['/library/a.flac']!.plays, 1);
    expect(history.tracks['/library/a.flac']!.recent, [now]);
  });

  test('GivenAPlayIsRecordedBeforeTheHistoryIsFirstWatched_WhenItIsWatched_ThenThePlayIsInIt', () async {
    final harness = Harness(now: now);
    await harness.read(playRecorderProvider).record('/library/a.flac');

    final history = await harness.read(playHistoryProvider.future);

    expect(history.tracks['/library/a.flac']!.plays, 1);
  });
}
