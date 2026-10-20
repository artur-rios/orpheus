import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';

/// Splitting a batch of songs into what is looked up.
void main() {
  /// [count] songs of one album, numbered from 1.
  List<MusicEntry> album(
    String name, {
    required String artist,
    required int count,
    String idPrefix = '',
    String directory = defaultLibraryDirectory,
  }) => [
    for (var number = 1; number <= count; number++)
      entry(
        id: '$idPrefix$name-$number',
        title: 'Song $number',
        artist: artist,
        albumArtist: artist,
        album: name,
        track: number,
        directory: directory,
      ),
  ];

  /// A song of no album, in [directory].
  MusicEntry untitled(String id, String directory) =>
      entry(id: id, title: id, artist: 'Someone', directory: directory);

  /// An Ogg song: the fixture only makes `.flac` paths.
  MusicEntry ogg(String id, {String? album, String artist = 'Someone'}) =>
      MusicEntry(
        file: AudioFile(
          path: '/library/$id.ogg',
          sizeInBytes: 1024,
          modifiedAt: DateTime.utc(2026),
        ),
        metadata: TrackMetadata(
          title: id,
          artist: artist,
          albumArtist: artist,
          album: album,
        ),
      );

  List<String> paths(List<MusicEntry> entries) => [
    for (final entry in entries) entry.file.path,
  ];

  group('planBatch', () {
    test('GivenTwoAlbums_WhenPlanned_ThenTwoRecordsInArtistThenAlbumOrder', () {
      final songs = [
        ...album('Zooropa', artist: 'U2', count: 2),
        ...album('Kid A', artist: 'Radiohead', count: 2),
        ...album('Amnesiac', artist: 'Radiohead', count: 2),
      ];

      final plan = planBatch(songs, songs);

      expect(
        plan.units.map((unit) => unit.kind),
        everyElement(BatchUnitKind.record),
      );
      expect(plan.units.map((unit) => unit.songs.first.album), [
        'Amnesiac',
        'Kid A',
        'Zooropa',
      ]);
      expect(plan.notWritable, isEmpty);
    });

    test(
      'GivenSpellingsDifferingOnlyInCaseAndAccents_WhenPlanned_ThenOneRecord',
      () {
        final songs = [
          entry(
            id: 'a',
            title: 'Svefn-g-englar',
            artist: 'Sigur Rós',
            albumArtist: 'Sigur Rós',
            album: 'Takk...',
            track: 2,
          ),
          entry(
            id: 'b',
            title: 'Starálfur',
            artist: 'sigur ros',
            albumArtist: 'sigur ros',
            album: 'TAKK',
            track: 1,
          ),
        ];

        final plan = planBatch(songs, songs);

        expect(plan.units, hasLength(1));
        expect(plan.units.single.songs.map((song) => song.title), [
          'Starálfur',
          'Svefn-g-englar',
        ]);
      },
    );

    test('GivenCompilationIsOneRecord_WhenPlanned_ThenOneRecordUnderVariousArtists', () {
      final songs = [
        for (final (index, artist) in ['A', 'B', 'C', 'D'].indexed)
          entry(
            id: 'c$index',
            title: 'Song $index',
            artist: artist,
            albumArtist: 'Various Artists',
            album: 'Now 99',
            track: index + 1,
          ),
      ];

      final plan = planBatch(songs, songs);

      expect(plan.units, hasLength(1));
      expect(plan.units.single.kind, BatchUnitKind.record);
      expect(plan.units.single.songs, hasLength(4));
    });

    test('GivenBlankAlbumsByFolder_WhenPlanned_ThenEachFolderIsItsOwnRecordAndAFolderOfOneIsATrack', () {
      final songs = [
        for (var i = 0; i < 3; i++) untitled('a$i', '/music/a'),
        for (var i = 0; i < 3; i++) untitled('b$i', '/music/b'),
        untitled('c0', '/music/c'),
      ];

      final plan = planBatch(songs, songs);

      expect(
        plan.units.where((unit) => unit.kind == BatchUnitKind.record),
        hasLength(2),
      );
      final tracks = plan.units
          .where((unit) => unit.kind == BatchUnitKind.track)
          .toList();
      expect(tracks, hasLength(1));
      expect(tracks.single.songs.single.file.directory, '/music/c');
      expect(plan.units.last.kind, BatchUnitKind.track);
    });

    test('GivenBlankAlbumsInAFolderOfTheLibraryOnly_WhenPlanned_ThenTheBatchSongIsARecordCarryingTheFolder', () {
      final folder = [for (var i = 0; i < 3; i++) untitled('a$i', '/music/a')];

      final plan = planBatch([folder.first], folder);

      expect(plan.units.single.kind, BatchUnitKind.record);
      expect(plan.units.single.songs, hasLength(1));
      expect(plan.units.single.matchAgainst, hasLength(3));
      expect(plan.units.single.partial, isTrue);
    });

    test('GivenPartialRecordCarriesTheWholeAlbum_WhenPlanned_ThenMatchAgainstHoldsTwelveAndSongsThree', () {
      final whole = album('OK Computer', artist: 'Radiohead', count: 12);

      final plan = planBatch(whole.take(3).toList(), whole);

      final unit = plan.units.single;
      expect(unit.songs, hasLength(3));
      expect(unit.matchAgainst, hasLength(12));
      expect(unit.partial, isTrue);
    });

    test('GivenABatchSongTheLibraryDoesNotHold_WhenPlanned_ThenMatchAgainstStillHoldsIt', () {
      final whole = album('OK Computer', artist: 'Radiohead', count: 12);
      final stale = whole.take(11).toList();

      final plan = planBatch(whole.skip(10).toList(), stale);

      final unit = plan.units.single;
      expect(paths(unit.matchAgainst), paths(whole));
      expect(unit.songs, hasLength(2));
    });

    test('GivenOggSongs_WhenPlanned_ThenCountedNotWritableAndTheirAllOggRecordDropped', () {
      final songs = [
        ogg('one', album: 'Vorbis'),
        ogg('two', album: 'Vorbis'),
        ...album('Kid A', artist: 'Radiohead', count: 2),
      ];

      final plan = planBatch(songs, songs);

      expect(plan.units, hasLength(1));
      expect(plan.units.single.songs.first.album, 'Kid A');
      expect(plan.notWritable, hasLength(2));
      expect(plan.songCount, 4);
    });

    test('GivenAnUnwritableSongOfARecordTheBatchHolds_WhenPlanned_ThenItIsCountedAndTheRecordIsNotPartial', () {
      final songs = [
        ...album('Kid A', artist: 'Radiohead', count: 2),
        ogg('three', album: 'Kid A', artist: 'Radiohead'),
      ];

      final plan = planBatch(songs, songs);

      expect(plan.units.single.songs, hasLength(2));
      expect(plan.units.single.matchAgainst, hasLength(3));
      expect(plan.units.single.partial, isFalse);
      expect(plan.notWritable, hasLength(1));
    });

    test('GivenAWholeWritableAlbum_WhenPlanned_ThenNotPartial', () {
      final whole = album('OK Computer', artist: 'Radiohead', count: 12);

      final plan = planBatch(whole, whole);

      expect(plan.units.single.partial, isFalse);
    });

    test('GivenTheSameSongTwice_WhenPlanned_ThenCountedOnce', () {
      final songs = album('Kid A', artist: 'Radiohead', count: 2);

      final plan = planBatch([...songs, songs.first], songs);

      expect(plan.songCount, 2);
      expect(plan.units.single.songs, hasLength(2));
    });

    test('GivenSongsOutOfOrderAcrossDiscs_WhenPlanned_ThenDiscThenTrackOrderWithAMissingDiscFirst', () {
      final songs = [
        entry(
          id: 'd2t1',
          title: 'D2T1',
          album: 'Set',
          artist: 'X',
          disc: 2,
          track: 1,
        ),
        entry(
          id: 'd1t2',
          title: 'D1T2',
          album: 'Set',
          artist: 'X',
          disc: 1,
          track: 2,
        ),
        entry(id: 'nodisc1', title: 'N1', album: 'Set', artist: 'X', track: 1),
      ];

      final plan = planBatch(songs, songs);

      expect(plan.units.single.songs.map((song) => song.title), [
        'N1',
        'D1T2',
        'D2T1',
      ]);
    });

    test(
      'GivenTwoLoneTracks_WhenPlanned_ThenTheyFollowTheRecordsInPathOrder',
      () {
        final songs = [
          untitled('z', '/music/z'),
          ...album('Kid A', artist: 'Radiohead', count: 2),
          untitled('a', '/music/a'),
        ];

        final plan = planBatch(songs, songs);

        expect(plan.units.map((unit) => unit.kind), [
          BatchUnitKind.record,
          BatchUnitKind.track,
          BatchUnitKind.track,
        ]);
        expect(plan.units[1].songs.single.file.directory, '/music/a');
        expect(plan.units[2].songs.single.file.directory, '/music/z');
        expect(plan.units[1].matchAgainst, plan.units[1].songs);
      },
    );

    test('GivenRecordsAndTracks_WhenKeyed_ThenEachKeyIsStableAndDistinct', () {
      final kidA = album('Kid A', artist: 'Radiohead', count: 2);
      final folder = [for (var i = 0; i < 2; i++) untitled('f$i', '/music/f')];
      final lone = untitled('lone', '/music/l');
      final songs = [...kidA, ...folder, lone];

      final keys = planBatch(songs, songs).units.map((unit) => unit.key);

      expect(keys, contains('folder:/music/f'));
      expect(keys, contains('track:${lone.file.path}'));
      expect(keys.toSet(), hasLength(3));
      expect(
        planBatch(kidA, kidA).units.single.key,
        planBatch(kidA.reversed.toList(), kidA).units.single.key,
      );
    });
  });

  group('estimatedMinutes', () {
    BatchPlan units(int count) => BatchPlan(
      units: [
        for (var i = 0; i < count; i++)
          BatchUnit(
            kind: BatchUnitKind.track,
            songs: [entry(id: 'u$i')],
            matchAgainst: [entry(id: 'u$i')],
          ),
      ],
      notWritable: const [],
    );

    test('Given288UnitsWithoutCover_WhenEstimated_Then12Minutes', () {
      expect(estimatedMinutes(units(288), AutofillField.defaults), 12);
    });

    test('Given288UnitsWithCover_WhenEstimated_Then17Minutes', () {
      expect(
        estimatedMinutes(units(288), {
          ...AutofillField.defaults,
          AutofillField.cover,
        }),
        17,
      );
    });

    test('GivenNothingToLookUp_WhenEstimated_ThenOneMinute', () {
      expect(estimatedMinutes(units(0), AutofillField.defaults), 1);
    });
  });
}
