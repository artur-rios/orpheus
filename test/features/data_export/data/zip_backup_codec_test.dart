import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/data/zip_backup_codec.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';

/// Writing a backup to its ZIP and reading it, or a bare data file, back.
void main() {
  final createdAt = DateTime.utc(2026, 10, 19, 8, 30);

  const preferences = PreferencesSnapshot(
    themeMode: 'light',
    locale: null,
    opensPlayerOnPlay: true,
    rescansAtStartup: false,
    fetchesLyricsOnline: true,
    checksForUpdatesOnStartup: false,
    showsAutoPlaylists: true,
    volume: 0.5,
    libraryFolders: [r'D:\Music'],
  );

  Map<String, Object?> data({
    int version = 1,
    String format = 'orpheus-data',
  }) => {
    'format': format,
    'formatVersion': version,
    'exportedAt': '2026-10-18T22:30:00.000Z',
    'orpheusVersion': '1.4.0',
    'songs': <Object?>[],
    'playlists': <Object?>[],
    'problems': <Object?>[],
  };

  Uint8List json(Object? document) =>
      Uint8List.fromList(utf8.encode(jsonEncode(document)));

  Map<String, Object?> manifest({
    int version = 1,
    String format = 'orpheus-backup',
  }) => {
    'format': format,
    'formatVersion': version,
    'createdAt': '2026-10-19T08:30:00.000Z',
    'orpheusVersion': '1.4.0',
    'contents': ['data.json'],
  };

  /// A ZIP assembled by hand, to make the files a writer here never would.
  Uint8List zip(Map<String, List<int>> files) {
    final archive = Archive();
    files.forEach((name, bytes) => archive.add(ArchiveFile.bytes(name, bytes)));

    return ZipEncoder().encodeBytes(archive);
  }

  BackupReadFailure? failureOf(Uint8List bytes) {
    try {
      readBackup(bytes);
    } on BackupReadFailure catch (failure) {
      return failure;
    }

    return null;
  }

  group('a backup ZIP', () {
    test(
      'GivenDataPreferencesAndTwoCovers_WhenWrittenAndRead_ThenAllReturn',
      () {
        final covers = {
          'p1': Uint8List.fromList([1, 2, 3]),
          'p2': Uint8List.fromList([255, 216, 255, 0]),
        };

        final bytes = encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: covers,
          createdAt: createdAt,
          orpheusVersion: '1.4.0',
        );
        final back = readBackup(bytes);

        expect(back.data, data());
        expect(back.preferences, preferences);
        expect(back.covers, covers);
        expect(back.createdAt, createdAt);
        expect(back.isFullBackup, isTrue);
      },
    );

    test('GivenNoCovers_WhenWrittenAndRead_ThenThereAreNone', () {
      final back = readBackup(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: const {},
          createdAt: createdAt,
        ),
      );

      expect(back.covers, isEmpty);
      expect(back.preferences, preferences);
    });

    test('GivenABackup_WhenOpenedAsAZip_ThenItHoldsTheDocumentedFiles', () {
      final bytes = encodeBackupZip(
        data: data(),
        preferences: preferences,
        covers: {
          'p1': Uint8List.fromList([9]),
        },
        createdAt: createdAt,
        orpheusVersion: '1.4.0',
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = [for (final file in archive.files) file.name];

      expect(
        names,
        containsAll(['backup.json', 'data.json', 'preferences.json']),
      );
      expect(names, contains('covers/p1'));

      final manifestFile = archive.findFile('backup.json')!;
      final written = jsonDecode(
        utf8.decode(manifestFile.readBytes()!),
      ) as Map<String, Object?>;
      expect(written['contents'], [
        'data.json',
        'preferences.json',
        'covers/p1',
      ]);
      expect(written['orpheusVersion'], '1.4.0');
    });

    test('GivenTheDataDocument_WhenWritten_ThenItIsExactlyTheJsonExport', () {
      final archive = ZipDecoder().decodeBytes(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: const {},
          createdAt: createdAt,
        ),
      );

      final text = utf8.decode(archive.findFile('data.json')!.readBytes()!);

      expect(text, endsWith('\n'));
      expect(text, contains('\n  "format": "orpheus-data"'));
    });
  });

  group('a data JSON on its own', () {
    test('GivenADataDocument_WhenRead_ThenItIsNotAFullBackup', () {
      final back = readBackup(json(data()));

      expect(back.isFullBackup, isFalse);
      expect(back.data, data());
      expect(back.preferences, isNull);
      expect(back.covers, isEmpty);
    });

    test('GivenTheExportsOwnBytes_WhenRead_ThenItReadsToo', () {
      const encoder = JsonEncoder.withIndent('  ');
      final bytes = Uint8List.fromList(
        utf8.encode('${encoder.convert(data())}\n'),
      );

      expect(readBackup(bytes).data['format'], 'orpheus-data');
    });

    test('GivenADataDocument_WhenRead_ThenItWasMadeWhenItWasExported', () {
      final back = readBackup(json(data()));

      expect(back.createdAt, DateTime.utc(2026, 10, 18, 22, 30));
    });
  });

  group('a file that is not accepted', () {
    test('GivenRandomBytes_WhenRead_ThenItIsNotABackup', () {
      final bytes = Uint8List.fromList([
        for (var i = 0; i < 300; i++) (i * 37) % 251,
      ]);

      expect(failureOf(bytes), isA<NotABackup>());
    });

    test('GivenNoBytes_WhenRead_ThenItIsNotABackup', () {
      expect(failureOf(Uint8List(0)), isA<NotABackup>());
    });

    test('GivenJsonThatIsNotAnObject_WhenRead_ThenItIsNotABackup', () {
      expect(failureOf(json([1, 2])), isA<NotABackup>());
    });

    test('GivenATruncatedZip_WhenRead_ThenItIsNotABackup', () {
      final whole = encodeBackupZip(
        data: data(),
        preferences: preferences,
        covers: const {},
        createdAt: createdAt,
      );

      expect(
        failureOf(Uint8List.sublistView(whole, 0, whole.length ~/ 2)),
        isA<NotABackup>(),
      );
    });

    test('GivenAZipWithoutBackupJson_WhenRead_ThenItIsNotABackup', () {
      final bytes = zip({'data.json': json(data())});

      expect(failureOf(bytes), isA<NotABackup>());
    });

    test('GivenAZipWithoutDataJson_WhenRead_ThenItIsNotABackup', () {
      final bytes = zip({'backup.json': json(manifest())});

      expect(failureOf(bytes), isA<NotABackup>());
    });

    test('GivenABackupJsonOfAnotherFormat_WhenRead_ThenItIsNotABackup', () {
      final bytes = zip({
        'backup.json': json(manifest(format: 'something-else')),
        'data.json': json(data()),
      });

      expect(failureOf(bytes), isA<NotABackup>());
    });

    test('GivenADataJsonOfAnotherFormat_WhenRead_ThenItIsNotABackup', () {
      expect(
        failureOf(json(data(format: 'something-else'))),
        isA<NotABackup>(),
      );
    });

    test(
      'GivenAZipWithADataJsonOfAnotherFormat_WhenRead_ThenItIsNotABackup',
      () {
        final bytes = zip({
          'backup.json': json(manifest()),
          'data.json': json(data(format: 'something-else')),
        });

        expect(failureOf(bytes), isA<NotABackup>());
      },
    );

    test('GivenAVersionThatIsNotANumber_WhenRead_ThenItIsNotABackup', () {
      final document = data()..['formatVersion'] = 'one';

      expect(failureOf(json(document)), isA<NotABackup>());
    });
  });

  group('a file from a newer Orpheus', () {
    test('GivenANewerBackupVersion_WhenRead_ThenItSaysWhichVersion', () {
      final bytes = zip({
        'backup.json': json(manifest(version: 2)),
        'data.json': json(data()),
      });

      final failure = failureOf(bytes);

      expect(failure, isA<NewerBackupVersion>());
      expect((failure! as NewerBackupVersion).version, 2);
    });

    test('GivenANewerDataVersionInsideAZip_WhenRead_ThenItIsNewer', () {
      final bytes = zip({
        'backup.json': json(manifest()),
        'data.json': json(data(version: 3)),
      });

      final failure = failureOf(bytes);

      expect(failure, isA<NewerBackupVersion>());
      expect((failure! as NewerBackupVersion).version, 3);
    });

    test('GivenANewerDataJson_WhenRead_ThenItIsNewer', () {
      final failure = failureOf(json(data(version: 2)));

      expect(failure, isA<NewerBackupVersion>());
      expect((failure! as NewerBackupVersion).version, 2);
    });
  });
}
