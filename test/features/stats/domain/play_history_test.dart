import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

/// Counting plays, and keeping the dates of the recent ones.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);

  test(
    'GivenATrackNeverPlayed_WhenAPlayIsRecorded_ThenItsDateIsItsOnlyRecentPlay',
    () {
      final history = PlayHistory.empty.recording('/library/a.flac', now);

      expect(history.tracks['/library/a.flac']!.recent, [now]);
    },
  );

  test(
    'GivenATrackPlayedBefore_WhenItIsPlayedAgain_ThenTheNewDateIsAppendedLast',
    () {
      final earlier = now.subtract(const Duration(days: 2));
      final history = PlayHistory.empty
          .recording('/library/a.flac', earlier)
          .recording('/library/a.flac', now);

      final track = history.tracks['/library/a.flac']!;
      expect(track.plays, 2);
      expect(track.lastPlayedAt, now);
      expect(track.recent, [earlier, now]);
    },
  );

  test(
    'GivenAPlayStampedInLocalTime_WhenItIsRecorded_ThenItsRecentDateIsUtc',
    () {
      final local = DateTime(2026, 10, 18, 9, 30);

      final history = PlayHistory.empty.recording('/library/a.flac', local);

      final recent = history.tracks['/library/a.flac']!.recent.single;
      expect(recent.isUtc, isTrue);
      expect(recent, local.toUtc());
    },
  );

  test('GivenACountCarriedOverWithNoDates_WhenItIsPlayedAgain_ThenTheCountGoesOnAndOnlyTheNewPlayIsDated', () {
    final history = PlayHistory(
      tracks: {
        '/library/a.flac': TrackPlays(
          path: '/library/a.flac',
          plays: 41,
          lastPlayedAt: DateTime.utc(2025, 3, 1),
        ),
      },
    ).recording('/library/a.flac', now);

    final track = history.tracks['/library/a.flac']!;
    expect(track.plays, 42);
    expect(track.recent, [now]);
  });

  test('GivenPlaysOlderThanNinetyDaysOnEveryTrack_WhenTheHistoryIsTrimmed_ThenOnlyTheirOldDatesGo', () {
    final old = now.subtract(const Duration(days: 91));
    final recent = now.subtract(const Duration(days: 3));
    final history = PlayHistory(
      tracks: {
        '/library/a.flac': TrackPlays(
          path: '/library/a.flac',
          plays: 7,
          lastPlayedAt: recent,
          recent: [old, recent],
        ),
        '/library/b.flac': TrackPlays(
          path: '/library/b.flac',
          plays: 2,
          lastPlayedAt: old,
          recent: [old],
        ),
      },
    );

    final trimmed = history.trimmedTo(now);

    expect(trimmed.tracks['/library/a.flac']!.recent, [recent]);
    expect(trimmed.tracks['/library/b.flac']!.recent, isEmpty);
    // The counts are the owner's history; only the dates are a window.
    expect(trimmed.tracks['/library/a.flac']!.plays, 7);
    expect(trimmed.tracks['/library/b.flac']!.plays, 2);
    expect(trimmed.tracks['/library/b.flac']!.lastPlayedAt, old);
    expect(trimmed.totalPlays, 9);
  });

  test(
    'GivenAPlayExactlyNinetyDaysOld_WhenTheHistoryIsTrimmed_ThenItIsKept',
    () {
      final edge = now.subtract(recentPlaysKept);
      final history = PlayHistory(
        tracks: {
          '/library/a.flac': TrackPlays(
            path: '/library/a.flac',
            plays: 1,
            lastPlayedAt: edge,
            recent: [edge],
          ),
        },
      );

      expect(history.trimmedTo(now).tracks['/library/a.flac']!.recent, [edge]);
    },
  );

  test('GivenTheWindow_WhenItIsRead_ThenItIsNinetyDays', () {
    expect(recentPlaysKept, const Duration(days: 90));
  });
}
