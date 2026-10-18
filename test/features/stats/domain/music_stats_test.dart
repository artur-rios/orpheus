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
    'GivenTwoRecordsShareATitle_WhenTheAlbumsAreRanked_ThenTheirPlaysAreNotAddedTogether',
    () {
      // Ranked by the record, not by the words on its spine. Keyed by title
      // alone, an owner's three plays of one artist's Greatest Hits and four
      // of another's became one line claiming seven plays of something they
      // never played.
      final records = albumArtistsAcross([
        entry(id: 'a', title: 'A', artist: 'Aretha', albumArtist: 'Aretha',
            album: 'Greatest Hits', directory: '/library/aretha'),
        entry(id: 'b', title: 'B', artist: 'Bowie', albumArtist: 'Bowie',
            album: 'Greatest Hits', directory: '/library/bowie'),
      ]);

      final stats = musicStatsFrom(
        history: historyOf({
          '/library/aretha/zzz-a.flac': 3,
          '/library/bowie/zzz-b.flac': 4,
        }),
        catalog: MusicCatalog(entries: records),
      );

      expect(
        [for (final line in stats.albums) (line.name, line.plays)],
        [('Greatest Hits', 4), ('Greatest Hits', 3)],
      );
    },
  );

  test(
    'GivenTwoRankingsAreTied_WhenTheyAreOrdered_ThenTheirNamesAreComparedAsAReaderWould',
    () {
      // Case-insensitively, like every listing in the application. Raw string
      // order puts every capital above every lower-case letter, which is not
      // an order anybody reading a chart expects.
      final stats = musicStatsFrom(
        history: historyOf({
          '/library/zzz-x.flac': 2,
          '/library/zzz-y.flac': 2,
        }),
        catalog: catalogOf([
          entry(id: 'x', title: 'x', artist: 'beatles', album: 'b'),
          entry(id: 'y', title: 'y', artist: 'Abba', album: 'a'),
        ]),
      );

      expect([for (final line in stats.artists) line.name], ['Abba', 'beatles']);
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
      // Not counted as untagged: there is no file left to go and tag, and a
      // library that failed to load would otherwise report every track the
      // owner ever played as missing its tags.
      expect(stats.untaggedTracks, 0);
    },
  );

  test(
    'GivenTwoTracksThatShareATitle_WhenTheTracksAreRanked_ThenTheyAreTwoLines',
    () {
      // A track is a file. Keyed by title, five records that each open with
      // an "Intro" became one line at the top of the chart with all their
      // plays added together.
      final intros = albumArtistsAcross([
        entry(id: 'a', title: 'Intro', artist: 'Aretha', album: 'One',
            directory: '/library/aretha'),
        entry(id: 'b', title: 'Intro', artist: 'Bowie', album: 'Two',
            directory: '/library/bowie'),
        entry(id: 'c', title: 'Outro', artist: 'Bowie', album: 'Two',
            directory: '/library/bowie'),
      ]);

      final stats = musicStatsFrom(
        history: historyOf({
          intros[0].file.path: 3,
          intros[1].file.path: 3,
          intros[2].file.path: 4,
        }),
        catalog: MusicCatalog(entries: intros),
      );

      expect(
        [for (final line in stats.tracks) (line.name, line.plays)],
        [('Outro', 4), ('Intro', 3), ('Intro', 3)],
      );
    },
  );

  test(
    'GivenMoreArtistsThanTheRankingHolds_WhenTheLeadersShareIsWorkedOut_ThenItIsAShareOfEveryPlay',
    () {
      // The ranking keeps ten lines; the share is of everything it counted.
      // Worked out from the ten alone, a leader with 20 of 520 plays claimed
      // a sixth of the owner's listening.
      final many = [
        for (var index = 0; index < 51; index++)
          entry(id: 'artist$index', title: 'T$index', artist: 'Artist $index'),
      ];

      final stats = musicStatsFrom(
        history: historyOf({
          for (var index = 0; index < 51; index++)
            many[index].file.path: index == 0 ? 20 : 10,
        }),
        catalog: catalogOf(many),
        limit: 10,
      );

      expect(stats.artists, hasLength(10));
      expect(stats.artists.first.name, 'Artist 0');
      expect(stats.artists.first.share, closeTo(20 / 520, 0.0001));
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

  test(
    'GivenATrackTaggedRockAndPop_WhenItIsPlayed_ThenBothGenresAreCreditedItsPlays',
    () {
      final both = entry(id: 'both', title: 'T', genres: ['Rock', 'Pop']);

      final stats = musicStatsFrom(
        history: historyOf({both.file.path: 4}),
        catalog: catalogOf([both]),
      );

      expect(
        [for (final line in stats.genres) (line.name, line.plays)],
        [('Pop', 4), ('Rock', 4)],
      );
    },
  );

  test(
    'GivenATrackTaggedRockAndRock_WhenItIsPlayed_ThenRockIsCreditedOnce',
    () {
      // `splitGenres` never yields this, but a stored catalog could hold it.
      final twice = entry(id: 'twice', title: 'T', genres: ['Rock', 'rock']);

      final stats = musicStatsFrom(
        history: historyOf({twice.file.path: 3}),
        catalog: catalogOf([twice]),
      );

      expect(
        [for (final line in stats.genres) (line.name, line.plays)],
        [('Rock', 3)],
      );
    },
  );

  test(
    'GivenRockSpelledTwoWaysAcrossTheLibrary_WhenRanked_ThenOneLineNamedByTheCommonSpelling',
    () {
      final a = entry(id: 'a', title: 'A', genres: ['rock']);
      final b = entry(id: 'b', title: 'B', genres: ['Rock']);
      final c = entry(id: 'c', title: 'C', genres: ['Rock']);

      final stats = musicStatsFrom(
        history: historyOf({
          a.file.path: 1,
          b.file.path: 2,
          c.file.path: 3,
        }),
        catalog: catalogOf([a, b, c]),
      );

      expect(
        [for (final line in stats.genres) (line.name, line.plays)],
        [('Rock', 6)],
      );
    },
  );

  test(
    'GivenTenPlaysOfARockAndPopTrack_WhenRanked_ThenEachGenresShareIsOfAllPlays',
    () {
      // Ten plays of a Rock;Pop track and ten of one with no genre: every
      // genre is half of what was played, so shares add up past the share of
      // any one line rather than being squeezed to fill 100% between them.
      final tagged = entry(id: 'tagged', title: 'T', genres: ['Rock', 'Pop']);
      final bare = entry(id: 'bare', title: 'B');

      final stats = musicStatsFrom(
        history: historyOf({tagged.file.path: 10, bare.file.path: 10}),
        catalog: catalogOf([tagged, bare]),
      );

      expect(
        [for (final line in stats.genres) (line.name, line.share)],
        [('Pop', 0.5), ('Rock', 0.5)],
      );
    },
  );

  test(
    'GivenTracksSharingAGenre_WhenRanked_ThenSharesMaySumPastAWholeBecauseATrackCountsTwice',
    () {
      // Pop is on every play there was, Rock on half of them. Divided by the
      // sum of the genres' own counts they would be a third and two thirds.
      final both = entry(id: 'both', title: 'T', genres: ['Rock', 'Pop']);
      final popOnly = entry(id: 'pop', title: 'P', genres: ['Pop']);

      final stats = musicStatsFrom(
        history: historyOf({both.file.path: 10, popOnly.file.path: 10}),
        catalog: catalogOf([both, popOnly]),
      );

      expect(
        [for (final line in stats.genres) (line.name, line.share)],
        [('Pop', 1.0), ('Rock', 0.5)],
      );
    },
  );

  test(
    'GivenATrackWithNoGenres_WhenPlayedWithNoArtistOrRecord_ThenItCountsAsUntagged',
    () {
      final bare = entry(id: 'bare', title: 'B');
      final tagged = entry(id: 'tagged', title: 'T', genres: ['Rock']);

      final stats = musicStatsFrom(
        history: historyOf({bare.file.path: 1, tagged.file.path: 1}),
        catalog: catalogOf([bare, tagged]),
      );

      // Only the file with nothing at all is untagged; a genre alone is a tag.
      expect(stats.untaggedTracks, 1);
    },
  );
}
