import 'dart:convert';
import 'dart:io';
import 'dart:math';
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

    test('GivenACoverOverTheLimit_WhenRead_ThenItIsSkippedAndNamed', () {
      final back = readBackup(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: {
            'big': Uint8List(maxBackupCoverBytes + 1),
            'small': Uint8List.fromList([1, 2, 3]),
          },
          createdAt: createdAt,
        ),
      );

      expect(back.covers.keys, ['small']);
      expect(back.skippedCovers, {'big'});
    });

    test('GivenACoverAtTheLimit_WhenRead_ThenItIsKept', () {
      final back = readBackup(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: {'exact': Uint8List(maxBackupCoverBytes)},
          createdAt: createdAt,
        ),
      );

      expect(back.covers['exact'], hasLength(maxBackupCoverBytes));
      expect(back.skippedCovers, isEmpty);
    });

    test('GivenACoverWhoseHeaderUnderstatesItsSize_WhenRead_ThenItIsSkipped', () {
      // A header can say less than the entry holds.
      final archive = ZipDecoder().decodeBytes(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: const {},
          createdAt: createdAt,
        ),
      )..add(ArchiveFile('covers/liar', 10, Uint8List(maxBackupCoverBytes + 1)));

      final back = readBackup(ZipEncoder().encodeBytes(archive));

      expect(back.covers, isEmpty);
      expect(back.skippedCovers, {'liar'});
    });

    test('GivenACoverWhoseHeaderDeclaresTooMuch_WhenRead_ThenItIsSkipped', () {
      final archive = ZipDecoder().decodeBytes(
        encodeBackupZip(
          data: data(),
          preferences: preferences,
          covers: const {},
          createdAt: createdAt,
        ),
      )..add(ArchiveFile('covers/big', maxBackupCoverBytes + 1, [1, 2, 3]));

      final back = readBackup(ZipEncoder().encodeBytes(archive));

      expect(back.covers, isEmpty);
      expect(back.skippedCovers, {'big'});
    });

    test('GivenACoverWithACorruptDeflateStream_WhenRead_ThenItIsSkippedAndTheRestIsKept', () {
      final bytes = encodeBackupZip(
        data: data(),
        preferences: preferences,
        covers: {
          'bad': Uint8List.fromList([for (var i = 0; i < 400; i++) i % 7]),
          'good': Uint8List.fromList([1, 2, 3]),
        },
        createdAt: createdAt,
      );
      // The entry's compressed bytes follow its name in the local header.
      final name = utf8.encode('covers/bad');
      var at = 0;
      while (!_startsWith(bytes, name, at)) {
        at++;
      }
      for (var i = 0; i < 8; i++) {
        bytes[at + name.length + i] = 0xff;
      }

      final back = readBackup(bytes);

      expect(back.covers.keys, ['good']);
      expect(back.skippedCovers, {'bad'});
      expect(back.data, data());
    });

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
      expect(back.skippedCovers, isEmpty);
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

  group('inflating a cover within the limit', () {
    // Raw deflate, as a ZIP stores it, cut into pieces of 1 KB.
    List<Uint8List> deflated(int length) {
      final all = Uint8List.fromList(
        ZLibCodec(raw: true).encode(Uint8List(length)),
      );

      return [
        for (var at = 0; at < all.length; at += 1024)
          Uint8List.sublistView(all, at, min(at + 1024, all.length)),
      ];
    }

    test('GivenAStreamWithinTheLimit_WhenInflated_ThenAllTheBytesComeBack', () {
      final bytes = inflateRawWithin(deflated(5000), 5000);

      expect(bytes, hasLength(5000));
    });

    test('GivenAStreamThatInflatesPastTheLimit_WhenInflated_ThenItAbortsEarlyAndAnswersNull', () {
      final pieces = deflated(100 * 1024 * 1024);
      var read = 0;

      final bytes = inflateRawWithin(
        pieces.map((piece) {
          read++;

          return piece;
        }),
        maxBackupCoverBytes,
      );

      expect(bytes, isNull);
      // Stopped near a fifth of the way through, not after inflating it all.
      expect(read, lessThan(pieces.length ~/ 2));
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

bool _startsWith(Uint8List bytes, List<int> prefix, int at) {
  if (at + prefix.length > bytes.length) {
    throw StateError('the name is not in the file');
  }
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[at + i] != prefix[i]) return false;
  }

  return true;
}
