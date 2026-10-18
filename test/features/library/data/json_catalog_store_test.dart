import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/json_catalog_store.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

import '../../../support/entries.dart';

/// Keeping the library between runs.
void main() {
  late Directory directory;
  late JsonCatalogStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-catalog');
    store = JsonCatalogStore(directory.path);
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test(
    'GivenAScannedLibrary_WhenItIsWrittenAndReadBack_ThenEveryTagSurvives',
    () async {
      final catalog = MusicCatalog(
        entries: albumArtistsAcross([
          entry(
            id: '1',
            title: 'Airbag',
            artist: 'Radiohead',
            album: 'OK Computer',
            track: 1,
            disc: 1,
            year: 1997,
            coverId: 'abc123',
            duration: const Duration(minutes: 4, seconds: 44),
          ),
        ]),
        scannedAt: DateTime.utc(2026, 6, 1, 12),
      );

      await store.write(catalog);
      final read = await store.read();

      final restored = read.entries.single;
      expect(restored.title, 'Airbag');
      expect(restored.artist, 'Radiohead');
      expect(restored.album, 'OK Computer');
      expect(restored.metadata.track, 1);
      expect(restored.metadata.disc, 1);
      expect(restored.metadata.year, 1997);
      expect(restored.metadata.coverId, 'abc123');
      expect(restored.duration, const Duration(minutes: 4, seconds: 44));
      expect(read.scannedAt, DateTime.utc(2026, 6, 1, 12));
    },
  );

  test(
    'GivenNoCatalogHasEverBeenWritten_WhenItIsRead_ThenTheLibraryIsEmptyRatherThanAFailure',
    () async {
      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenACatalogThatWillNotParse_WhenItIsRead_ThenTheLibraryIsEmptyAndTheLaunchGoesOn',
    () async {
      // A catalog nobody can decode is a catalog nobody has, and the answer to
      // that is an empty library and a re-scan, not a launch that fails.
      File(store.path).writeAsStringSync('{ this is not json');

      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenACatalogWrittenByAnotherVersion_WhenItIsRead_ThenItIsDiscardedRatherThanHalfRead',
    () async {
      File(store.path).writeAsStringSync('{"version": 99, "tracks": []}');

      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenAWrittenCatalog_WhenItIsCleared_ThenNothingIsLeftOnDisk',
    () async {
      await store.write(
        MusicCatalog(entries: [entry(id: '1', title: 'Gone')]),
      );

      await store.clear();

      expect(File(store.path).existsSync(), isFalse);
    },
  );

  test(
    'GivenAReadCatalog_WhenATrackIsLookedUpByItsFile_ThenTheLibrarysOwnEntryComesBack',
    () async {
      await store.write(
        MusicCatalog(entries: [entry(id: '1', title: 'Airbag')]),
      );
      final read = await store.read();

      expect(read.entryFor(file('1')).title, 'Airbag');
    },
  );

  test(
    'GivenAFileTheLibraryDoesNotHold_WhenItIsLookedUp_ThenItReadsAsUntaggedRatherThanMissing',
    () async {
      // Such a file is still playable, and every caller wants something to
      // name it by.
      final catalog = MusicCatalog(entries: [entry(id: '1')]);

      expect(catalog.entryFor(file('999')).title, isNull);
      expect(catalog.entryAt(file('999').path), isNull);
    },
  );

  test(
    'GivenEntriesWithSeveralGenres_WhenTheCatalogIsWrittenAndRead_ThenTheGenresComeBackInOrder',
    () async {
      await store.write(
        MusicCatalog(
          entries: [
            entry(id: '1', title: 'A', genres: ['Rock', 'Hip-Hop/Rap', 'Pop']),
            entry(id: '2', title: 'B', genres: ['Jazz']),
          ],
        ),
      );

      final read = await store.read();

      expect(read.entryFor(file('1')).genres, ['Rock', 'Hip-Hop/Rap', 'Pop']);
      expect(read.entryFor(file('2')).genres, ['Jazz']);
    },
  );

  test(
    'GivenAnEntryWithNoGenre_WhenTheCatalogIsWritten_ThenItsRowHasNoGenresKey',
    () async {
      await store.write(MusicCatalog(entries: [entry(id: '1', title: 'A')]));

      final document =
          jsonDecode(File(store.path).readAsStringSync())
              as Map<String, dynamic>;
      final row = (document['tracks'] as List).single as Map<String, dynamic>;

      expect(row.containsKey('genres'), isFalse);
      expect(row.containsKey('genre'), isFalse);
      expect((await store.read()).entryFor(file('1')).genres, isEmpty);
    },
  );

  test(
    'GivenAStoredGenresListWithANonStringItem_WhenTheCatalogIsRead_ThenThatItemIsSkipped',
    () async {
      File(store.path).writeAsStringSync(
        jsonEncode({
          'version': JsonCatalogStore.documentVersion,
          'tracks': [
            {
              'path': file('1').path,
              'genres': ['Rock', 7, null, 'Pop'],
            },
          ],
        }),
      );

      expect((await store.read()).entryFor(file('1')).genres, ['Rock', 'Pop']);
    },
  );

  test(
    'GivenADocumentWrittenAsVersion1_WhenTheCatalogIsRead_ThenItIsRefusedForARescan',
    () async {
      File(store.path).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'tracks': [
            {'path': file('1').path, 'genre': 'Rock'},
          ],
        }),
      );

      expect(JsonCatalogStore.documentVersion, 2);
      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenADocumentWrittenAsVersion1_WhenTheCatalogIsRead_ThenItIsReportedAsStale',
    () async {
      // What startup scans on, whatever the owner's preference: a refused
      // document is a library that is empty until someone scans it.
      File(store.path).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'tracks': [
            {'path': file('1').path, 'genre': 'Rock'},
          ],
        }),
      );

      expect((await store.read()).isStale, isTrue);
    },
  );

  test(
    'GivenACurrentDocument_WhenTheCatalogIsRead_ThenItIsNotStale',
    () async {
      await store.write(MusicCatalog(entries: [entry(id: '1', title: 'A')]));

      expect((await store.read()).isStale, isFalse);
    },
  );

  test(
    'GivenNoDocument_WhenTheCatalogIsRead_ThenItIsNotStale',
    () async {
      // A library never scanned is not one this application broke; it is the
      // owner's preference that decides whether startup scans it.
      expect((await store.read()).isStale, isFalse);
    },
  );
}
