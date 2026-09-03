import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/stats/domain/music_stats.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';

/// Reading a play history against the catalog to make the four rankings.
void main() {
  final library = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: 'ok2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: 'blue', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue'),
  ];

  /// The library, grouped the way the application groups it.
  MusicCatalog catalogOf(List<MusicEntry> entries) =>
      MusicCatalog(entries: albumArtistsAcross(entries));

  PlayHistory historyOf(Map<String, int> plays) => PlayHistory(
    tracks: {
      for (final played in plays.entries)
        played.key: TrackPlays(
          path: played.key,
          plays: played.value,
          lastPlayedAt: DateTime.utc(2026),
        ),
    },
  );

  test(
    'GivenNothingHasBeenPlayed_WhenTheStatisticsAreRead_ThenTheyAreEmpty',
    () async {
      final stats = musicStatsFrom(
        history: PlayHistory.empty,
        catalog: catalogOf(library),
      );

      expect(stats.isEmpty, isTrue);
      expect(stats.totalPlays, 0);
      expect(stats.tracks, isEmpty);
    },
  );

  test(
    'GivenSeveralTracksPlayed_WhenTheStatisticsAreRead_ThenTheTotalsCountEveryPlay',
    () async {
      final stats = musicStatsFrom(
        history: historyOf({
          library[0].file.path: 5,
          library[1].file.path: 2,
        }),
        catalog: catalogOf(library),
      );

      expect(stats.totalPlays, 7);
      expect(stats.distinctTracks, 2);
    },
  );

  test(
    'GivenTracksOnOneRecord_WhenTheStatisticsAreRead_ThenTheirPlaysAddUpUnderTheArtistAndTheRecord',
    () async {
      final stats = musicStatsFrom(
        history: historyOf({
          library[0].file.path: 5,
          library[1].file.path: 2,
          library[2].file.path: 4,
        }),
        catalog: catalogOf(library),
      );

      expect(stats.artists.first.name, 'Radiohead');
      expect(stats.artists.first.plays, 7);
      expect(stats.albums.first.name, 'OK Computer');
      expect(stats.albums.first.plays, 7);
      // And the runner-up is still ranked, not dropped.
      expect(stats.artists[1].name, 'Miles Davis');
      expect(stats.artists[1].plays, 4);
    },
  );

  test(
    'GivenTracksWithDifferentPlayCounts_WhenTheStatisticsAreRead_ThenTheMostPlayedIsFirst',
    () async {
      final stats = musicStatsFrom(
        history: historyOf({
          library[0].file.path: 1,
          library[2].file.path: 9,
        }),
        catalog: catalogOf(library),
      );

      expect([for (final line in stats.tracks) line.name], [
        'So What',
        'Airbag',
      ]);
    },
  );

  test(
    'GivenTwoEntriesWithEqualPlays_WhenTheStatisticsAreRead_ThenTheyAreOrderedByName',
    () async {
      // A ranking whose equal rows swapped places between openings would be a
      // ranking nobody could trust they had read correctly.
      final stats = musicStatsFrom(
        history: historyOf({
          library[0].file.path: 3,
          library[2].file.path: 3,
        }),
        catalog: catalogOf(library),
      );

      expect([for (final line in stats.tracks) line.name], [
        'Airbag',
        'So What',
      ]);
    },
  );

  test(
    'GivenAPlayedFileTheCatalogNoLongerHolds_WhenTheStatisticsAreRead_ThenItStillCountsAndIsNamedByItsFile',
    () async {
      // Its plays happened. There are no tags left to rank it by, so it
      // contributes to the totals and the track list and to nothing else.
      final stats = musicStatsFrom(
        history: historyOf({'/gone/zzz-removed.flac': 3}),
        catalog: catalogOf(library),
      );

      expect(stats.totalPlays, 3);
      expect(stats.tracks.single.name, 'zzz-removed.flac');
      expect(stats.artists, isEmpty);
      expect(stats.albums, isEmpty);
      expect(stats.untaggedTracks, 1);
    },
  );

  test(
    'GivenAPlayedTrackWithNoTags_WhenTheStatisticsAreRead_ThenItRanksNowhereButIsCountedAndExplained',
    () async {
      final untagged = entry(id: 'nothing');
      final catalog = MusicCatalog(
        entries: albumArtistsAcross([...library, untagged]),
      );

      final stats = musicStatsFrom(
        history: historyOf({
          library[0].file.path: 2,
          untagged.file.path: 5,
        }),
        catalog: catalog,
      );

      // Counted in the totals...
      expect(stats.totalPlays, 7);
      // ...named by its file among the tracks, because ten rows all called
      // "Untitled" is a ranking nobody can read...
      expect(stats.tracks.first.name, 'zzz-nothing.flac');
      // ...and ranked under no invented artist.
      expect([for (final line in stats.artists) line.name], ['Radiohead']);
      expect(stats.untaggedTracks, 1);
    },
  );

  test(
    'GivenMoreEntriesThanTheRankingHolds_WhenTheStatisticsAreRead_ThenOnlyTheTopOnesAreKept',
    () async {
      final many = [
        for (var index = 0; index < 15; index++)
          entry(id: 'many$index', title: 'Track $index', artist: 'A', album: 'B'),
      ];
      final catalog = MusicCatalog(entries: albumArtistsAcross(many));

      final stats = musicStatsFrom(
        history: historyOf({
          for (var index = 0; index < 15; index++) many[index].file.path: index + 1,
        }),
        catalog: catalog,
        limit: 10,
      );

      expect(stats.tracks.length, 10);
      expect(stats.tracks.first.name, 'Track 14');
      expect(stats.distinctTracks, 15);
    },
  );

  test(
    'GivenAGenreOfNothingButSpaces_WhenTheStatisticsAreRead_ThenItIsAbsentRatherThanRanked',
    () async {
      final blank = entry(id: 'blank', title: 'T', artist: 'A', album: 'B');
      final catalog = MusicCatalog(entries: albumArtistsAcross([blank]));

      final stats = musicStatsFrom(
        history: historyOf({blank.file.path: 1}),
        catalog: catalog,
      );

      expect(stats.genres, isEmpty);
    },
  );
}
