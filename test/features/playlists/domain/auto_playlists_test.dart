import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playlists/domain/auto_playlists.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';

/// The two lists worked out from what was played, and what is in the library.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);
  final cutoff = now.subtract(const Duration(days: 30));

  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  /// A track played [plays] times in all, last at [last], with [recent] dates.
  TrackPlays played(
    String path, {
    required int plays,
    required DateTime last,
    List<DateTime>? recent,
  }) => TrackPlays(
    path: path,
    plays: plays,
    lastPlayedAt: last,
    recent: recent ?? [last],
  );

  PlayHistory historyOf(List<TrackPlays> tracks) =>
      PlayHistory(tracks: {for (final track in tracks) track.path: track});

  String pathOf(int i) => entry(id: 's$i').file.path;

  /// The catalog of songs `s0`..`s{count-1}`, by path.
  Map<String, MusicEntry> libraryOf(int count) => {
    for (var i = 0; i < count; i++) pathOf(i): entry(id: 's$i'),
  };

  List<String> pathsOf(Iterable<MusicEntry> songs) => [
    for (final song in songs) song.file.path,
  ];

  /// Ten songs, `s0`..`s9`, each with one play a day ago: just enough.
  List<TrackPlays> tenRecent() => [
    for (var i = 0; i < 10; i++)
      played(pathOf(i), plays: 1, last: daysAgo(1), recent: [daysAgo(1)]),
  ];

  group('favourites lately', () {
    test('GivenTenSongsPlayedLately_WhenWorkedOut_ThenTheyAreOrderedByRecentPlaysThenLastPlay', () {
      final tracks = tenRecent();
      // s3 three times, s5 twice, s7 twice but more recently than s5.
      tracks[3] = played(
        pathOf(3),
        plays: 3,
        last: daysAgo(2),
        recent: [daysAgo(5), daysAgo(4), daysAgo(2)],
      );
      tracks[5] = played(
        pathOf(5),
        plays: 2,
        last: daysAgo(3),
        recent: [daysAgo(6), daysAgo(3)],
      );
      tracks[7] = played(
        pathOf(7),
        plays: 2,
        last: daysAgo(1),
        recent: [daysAgo(7), daysAgo(1)],
      );

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      expect(result.isFallback, isFalse);
      expect(pathsOf(result.songs).take(3), [pathOf(3), pathOf(7), pathOf(5)]);
      expect(result.songs, hasLength(10));
    });

    test('GivenSongsWithEqualRecentPlays_WhenWorkedOut_ThenTheMoreRecentlyPlayedIsFirst', () {
      final tracks = tenRecent();
      tracks[2] = played(pathOf(2), plays: 1, last: daysAgo(9));
      tracks[8] = played(pathOf(8), plays: 1, last: daysAgo(0));

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      expect(pathsOf(result.songs).first, pathOf(8));
      expect(pathsOf(result.songs).last, pathOf(2));
    });

    test(
      'GivenASongWithManyOldPlays_WhenWorkedOut_ThenOnlyItsRecentPlaysCount',
      () {
        final tracks = tenRecent();
        // Thirty plays in all, but only one of them within the window.
        tracks[0] = played(
          pathOf(0),
          plays: 30,
          last: daysAgo(1),
          recent: [daysAgo(60), daysAgo(50), daysAgo(1)],
        );
        tracks[1] = played(
          pathOf(1),
          plays: 2,
          last: daysAgo(10),
          recent: [daysAgo(11), daysAgo(10)],
        );

        final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

        expect(pathsOf(result.songs).first, pathOf(1));
      },
    );

    test(
      'GivenAPlayExactlyThirtyDaysAgo_WhenWorkedOut_ThenItCountsAsLately',
      () {
        final tracks = tenRecent();
        tracks[4] = played(pathOf(4), plays: 1, last: cutoff, recent: [cutoff]);

        final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

        expect(result.isFallback, isFalse);
        expect(pathsOf(result.songs), contains(pathOf(4)));
      },
    );

    test('GivenAPlayJustOverThirtyDaysAgo_WhenWorkedOut_ThenItDoesNotCountAsLately', () {
      final old = cutoff.subtract(const Duration(seconds: 1));
      final tracks = tenRecent();
      tracks[4] = played(pathOf(4), plays: 1, last: old, recent: [old]);

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      // Nine left with a recent play: below the ten, so the fallback — and
      // that song's last play is out of the window too.
      expect(result.isFallback, isTrue);
      expect(pathsOf(result.songs), isNot(contains(pathOf(4))));
      expect(result.songs, hasLength(9));
    });

    test(
      'GivenAPlayDatedAfterNow_WhenWorkedOut_ThenItDoesNotCountAsLately',
      () {
        final ahead = now.add(const Duration(days: 1));
        final tracks = tenRecent();
        tracks[4] = played(pathOf(4), plays: 1, last: ahead, recent: [ahead]);

        final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

        // Nine songs with a play that counts: below the ten.
        expect(result.isFallback, isTrue);
      },
    );

    test('GivenAPlayDatedExactlyNow_WhenWorkedOut_ThenItCountsAsLately', () {
      final tracks = tenRecent();
      tracks[4] = played(pathOf(4), plays: 1, last: now, recent: [now]);

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      expect(result.isFallback, isFalse);
      expect(pathsOf(result.songs).first, pathOf(4));
    });

    test('GivenNineSongsPlayedLately_WhenWorkedOut_ThenTheFallbackIsUsed', () {
      final tracks = tenRecent().take(9).toList();

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      expect(result.isFallback, isTrue);
      expect(result.songs, hasLength(9));
    });

    test('GivenTenSongsPlayedLatelyButOneIsMissing_WhenWorkedOut_ThenOnlyPresentSongsAreCounted', () {
      final library = libraryOf(10)..remove(pathOf(6));

      final result = favouritesLately(historyOf(tenRecent()), library, now);

      expect(result.isFallback, isTrue);
      expect(pathsOf(result.songs), isNot(contains(pathOf(6))));
      expect(result.songs, hasLength(9));
    });

    test('GivenFewerThanTenRecentSongs_WhenWorkedOut_ThenTheFallbackIsOrderedByPlaysThenLastPlay', () {
      // Played lately by last-play date, but their dated plays were not
      // recorded (a history migrated from before plays were dated).
      final tracks = [
        played(pathOf(0), plays: 5, last: daysAgo(3), recent: const []),
        played(pathOf(1), plays: 9, last: daysAgo(20), recent: const []),
        played(pathOf(2), plays: 5, last: daysAgo(1), recent: const []),
        played(pathOf(3), plays: 40, last: daysAgo(31), recent: const []),
      ];

      final result = favouritesLately(historyOf(tracks), libraryOf(10), now);

      expect(result.isFallback, isTrue);
      // s3's last play is out of the window, so it is not in; s1 has the
      // most plays; s2 and s0 tie and the more recent goes first.
      expect(pathsOf(result.songs), [pathOf(1), pathOf(2), pathOf(0)]);
    });

    test('GivenALastPlayExactlyThirtyDaysAgo_WhenTheFallbackIsUsed_ThenTheSongQualifies', () {
      final tracks = [
        played(pathOf(0), plays: 2, last: cutoff, recent: const []),
      ];

      final result = favouritesLately(historyOf(tracks), libraryOf(1), now);

      expect(result.isFallback, isTrue);
      expect(pathsOf(result.songs), [pathOf(0)]);
    });

    test('GivenNothingWasPlayedInTheLastThirtyDays_WhenWorkedOut_ThenItIsEmptyAndNotTheFallback', () {
      final tracks = [
        played(pathOf(0), plays: 8, last: daysAgo(45), recent: const []),
      ];

      final result = favouritesLately(historyOf(tracks), libraryOf(3), now);

      expect(result.songs, isEmpty);
      expect(result.isFallback, isFalse);
    });

    test(
      'GivenAnEmptyHistory_WhenWorkedOut_ThenItIsEmptyAndNotTheFallback',
      () {
        final result = favouritesLately(PlayHistory.empty, libraryOf(3), now);

        expect(result.songs, isEmpty);
        expect(result.isFallback, isFalse);
      },
    );

    test(
      'GivenRecentPlaysOfSongsNoLongerInTheLibrary_WhenWorkedOut_ThenItIsEmpty',
      () {
        final result = favouritesLately(historyOf(tenRecent()), const {}, now);

        expect(result.songs, isEmpty);
        expect(result.isFallback, isFalse);
      },
    );

    test('GivenMoreThanFiftySongsPlayedLately_WhenWorkedOut_ThenOnlyTheFirstFiftyAreKept', () {
      final tracks = [
        for (var i = 0; i < 60; i++)
          // Later numbers were played more, so they go first.
          played(
            pathOf(i),
            plays: i + 1,
            last: daysAgo(1),
            recent: [for (var n = 0; n <= i; n++) daysAgo(2)],
          ),
      ];

      final result = favouritesLately(historyOf(tracks), libraryOf(60), now);

      expect(result.isFallback, isFalse);
      expect(result.songs, hasLength(50));
      expect(pathsOf(result.songs).first, pathOf(59));
      expect(pathsOf(result.songs).last, pathOf(10));
    });

    test('GivenMoreThanFiftySongsInTheFallback_WhenWorkedOut_ThenOnlyTheFirstFiftyAreKept', () {
      final tracks = [
        for (var i = 0; i < 70; i++)
          played(pathOf(i), plays: i + 1, last: daysAgo(2), recent: const []),
      ];

      final result = favouritesLately(historyOf(tracks), libraryOf(70), now);

      expect(result.isFallback, isTrue);
      expect(result.songs, hasLength(50));
      expect(pathsOf(result.songs).first, pathOf(69));
      expect(pathsOf(result.songs).last, pathOf(20));
    });

    test(
      'GivenTimesInALocalZone_WhenWorkedOut_ThenTheyAreComparedAsInstants',
      () {
        // The same instant as exactly thirty days ago, written in a zone.
        final local = cutoff.toLocal();
        final tracks = tenRecent();
        tracks[0] = played(pathOf(0), plays: 1, last: local, recent: [local]);

        final result = favouritesLately(
          historyOf(tracks),
          libraryOf(10),
          now.toLocal(),
        );

        expect(result.isFallback, isFalse);
        expect(result.songs, hasLength(10));
      },
    );
  });

  group('all-time favourites', () {
    test(
      'GivenPlayedSongs_WhenWorkedOut_ThenTheyAreOrderedByPlaysThenLastPlay',
      () {
        final tracks = [
          played(pathOf(0), plays: 3, last: daysAgo(10)),
          played(pathOf(1), plays: 9, last: daysAgo(400), recent: const []),
          played(pathOf(2), plays: 3, last: daysAgo(2)),
          played(pathOf(3), plays: 1, last: daysAgo(1)),
        ];

        final result = allTimeFavourites(historyOf(tracks), libraryOf(5));

        expect(pathsOf(result), [pathOf(1), pathOf(2), pathOf(0), pathOf(3)]);
      },
    );

    test('GivenAnOldHistory_WhenWorkedOut_ThenSongsFromAnyTimeAreIn', () {
      final tracks = [
        played(pathOf(0), plays: 2, last: DateTime.utc(2019), recent: const []),
      ];

      final result = allTimeFavourites(historyOf(tracks), libraryOf(1));

      expect(pathsOf(result), [pathOf(0)]);
    });

    test('GivenASongNotInTheLibrary_WhenWorkedOut_ThenItIsLeftOut', () {
      final tracks = [
        played(pathOf(0), plays: 9, last: daysAgo(1)),
        played(pathOf(1), plays: 2, last: daysAgo(1)),
      ];
      final library = libraryOf(2)..remove(pathOf(0));

      final result = allTimeFavourites(historyOf(tracks), library);

      expect(pathsOf(result), [pathOf(1)]);
    });

    test('GivenATrackWithNoPlays_WhenWorkedOut_ThenItIsLeftOut', () {
      final tracks = [played(pathOf(0), plays: 0, last: daysAgo(1))];

      expect(allTimeFavourites(historyOf(tracks), libraryOf(1)), isEmpty);
    });

    test('GivenAnEmptyHistory_WhenWorkedOut_ThenItIsEmpty', () {
      expect(allTimeFavourites(PlayHistory.empty, libraryOf(3)), isEmpty);
    });

    test(
      'GivenMoreThanFiftyPlayedSongs_WhenWorkedOut_ThenTheFirstFiftyAreKept',
      () {
        final tracks = [
          for (var i = 0; i < 80; i++)
            played(pathOf(i), plays: i + 1, last: daysAgo(100)),
        ];

        final result = allTimeFavourites(historyOf(tracks), libraryOf(80));

        expect(result, hasLength(50));
        expect(pathsOf(result).first, pathOf(79));
        expect(pathsOf(result).last, pathOf(30));
      },
    );

    test('GivenSongsThatTieOnPlaysAndLastPlay_WhenHistoryOrderDiffers_ThenTheOrderIsTheSame', () {
      final tracks = [
        for (var i = 0; i < 5; i++)
          played(pathOf(i), plays: 2, last: daysAgo(3)),
      ];

      final first = allTimeFavourites(historyOf(tracks), libraryOf(5));
      final second = allTimeFavourites(
        historyOf(tracks.reversed.toList()),
        libraryOf(5),
      );

      expect(pathsOf(first), pathsOf(second));
    });
  });
}
