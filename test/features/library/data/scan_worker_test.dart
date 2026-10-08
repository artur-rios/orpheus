import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/json_catalog_store.dart';
import 'package:orpheus/features/library/data/scan_worker.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart';

/// Walking the owner's folders and reading what is in them.
///
/// Against a real temporary directory, because that is what the scanner is
/// for: every rule here — what is collected, what is stepped over, what is
/// re-read — is about the filesystem, and a fake one would only prove that the
/// fake agrees with the code.
void main() {
  late Directory root;
  late Directory covers;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orpheus-scan');
    covers = Directory('${root.path}/.cache/covers');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  // Joined rather than interpolated with a slash, because these paths are
  // compared against the ones the scan's own walk produces. On Windows a
  // fixture written to `C:\dir/a.flac` and walked as `C:\dir\a.flac` are two
  // different strings, and the carry-over lookup — which is keyed by path —
  // misses every time. That made the incremental-scan test fail on Windows for
  // a reason that had nothing to do with the scanner.
  File writeFile(String relative, List<int> bytes) {
    final file = File(p.joinAll([root.path, ...relative.split('/')]));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);

    return file;
  }

  void writeTrack(String relative, Map<String, String> tags, {List<int>? art}) =>
      writeFile(
        relative,
        taggedFlac(
          tags: tags,
          picture: art == null ? null : onePixelPng(),
        ),
      );

  ScanOutcome scan({
    List<MusicEntry> previous = const [],
    DateTime? unchangedSince,
  }) => scanFolders(
    folders: [root.path],
    previous: previous,
    coverDirectory: covers.path,
    unchangedSince: unchangedSince,
  );

  test(
    'GivenAFolderOfTaggedTracks_WhenItIsScanned_ThenEveryTrackIsReadWithItsTags',
    () {
      writeTrack('a.flac', {'TITLE': 'Airbag', 'ARTIST': 'Radiohead'});
      writeTrack('b.flac', {'TITLE': 'Karma', 'ARTIST': 'Radiohead'});

      final outcome = scan();

      expect(outcome.report.tracks, 2);
      expect(outcome.report.added, 2);
      expect(
        [for (final entry in outcome.entries) entry.title],
        ['Airbag', 'Karma'],
      );
    },
  );

  test(
    'GivenAFolderHoldingImagesAndDocuments_WhenItIsScanned_ThenOnlyTheAudioIsCollected',
    () {
      writeTrack('song.flac', {'TITLE': 'Song'});
      writeFile('notes.txt', 'nothing to hear'.codeUnits);
      writeFile('scan.pdf', 'nor here'.codeUnits);

      expect(scan().report.tracks, 1);
    },
  );

  test(
    'GivenAHiddenFolder_WhenTheLibraryIsScanned_ThenNothingInsideItIsCollected',
    () {
      // `.git`, `.Trash-1000` and `.thumbnails` hold nothing anybody wants in
      // their library, and walking them is the bulk of the cost of scanning a
      // home folder.
      writeTrack('keep.flac', {'TITLE': 'Keep'});
      writeTrack('.Trash-1000/deleted.flac', {'TITLE': 'Deleted'});

      final outcome = scan();

      expect([for (final entry in outcome.entries) entry.title], ['Keep']);
    },
  );

  test(
    'GivenNestedFolders_WhenTheLibraryIsScanned_ThenTracksAtEveryDepthAreCollected',
    () {
      writeTrack('Radiohead/OK Computer/01.flac', {'TITLE': 'Airbag'});
      writeTrack('Radiohead/Kid A/01.flac', {'TITLE': 'Everything'});

      expect(scan().report.tracks, 2);
    },
  );

  test(
    'GivenAFileWhoseTagsWillNotParse_WhenItIsScanned_ThenItStaysInTheLibraryAndIsReported',
    () {
      // It is very often a file that plays perfectly well. Dropping it would
      // take a track out of a library the owner can see it in.
      writeFile('broken.flac', 'not a flac file'.codeUnits);

      final outcome = scan();

      expect(outcome.report.tracks, 1);
      expect(outcome.entries.single.title, isNull);
      expect(outcome.report.unreadable.single, endsWith('broken.flac'));
    },
  );

  test(
    'GivenATrackWithAnEmbeddedCover_WhenItIsScanned_ThenThePictureIsStoredAndTheEntryPointsAtIt',
    () {
      writeTrack('a.flac', {'TITLE': 'With art'}, art: onePixelPng());

      final outcome = scan();
      final coverId = outcome.entries.single.metadata.coverId;

      expect(coverId, isNotNull);
      expect(File('${covers.path}/$coverId').existsSync(), isTrue);
    },
  );

  test(
    'GivenARecordWhoseTracksShareOnePicture_WhenItIsScanned_ThenThePictureIsStoredOnce',
    () {
      // Content-addressed: twelve tracks carrying the same JPEG are one file
      // on disk, which is what keeps the cache proportional to records rather
      // than to files.
      writeTrack('a.flac', {'TITLE': 'One'}, art: onePixelPng());
      writeTrack('b.flac', {'TITLE': 'Two'}, art: onePixelPng());

      final outcome = scan();

      expect(
        outcome.entries.first.metadata.coverId,
        outcome.entries.last.metadata.coverId,
      );
      expect(covers.listSync().length, 1);
    },
  );

  test(
    'GivenATrackWithNoEmbeddedArtBesideACoverFile_WhenItIsScanned_ThenTheSidecarIsUsed',
    () {
      writeTrack('LP/01.flac', {'TITLE': 'Bare'});
      writeFile('LP/cover.png', onePixelPng());

      expect(scan().entries.single.metadata.coverId, isNotNull);
    },
  );

  test(
    'GivenAFolderHoldingBothFolderAndCoverImages_WhenItIsScanned_ThenCoverIsPreferred',
    () {
      writeTrack('LP/01.flac', {'TITLE': 'Bare'});
      writeFile('LP/cover.png', onePixelPng());
      writeFile('LP/folder.png', 'a different picture entirely'.codeUnits);

      final coverId = scan().entries.single.metadata.coverId;

      expect(
        File('${covers.path}/$coverId').readAsBytesSync(),
        onePixelPng(),
      );
    },
  );

  test(
    'GivenThePreferredCoverFileIsEmpty_WhenTheFolderIsScanned_ThenTheNextOneIsUsed',
    () {
      // A zero-length `cover.jpg` is what a failed download leaves behind, not
      // a sleeve. Stopping at it hid the perfectly good `folder.png` beside
      // it, and the record showed no artwork at all.
      writeTrack('LP/01.flac', {'TITLE': 'Bare'});
      writeFile('LP/cover.png', <int>[]);
      writeFile('LP/folder.png', onePixelPng());

      final coverId = scan().entries.single.metadata.coverId;

      expect(coverId, isNotNull);
      expect(
        File('${covers.path}/$coverId').readAsBytesSync(),
        onePixelPng(),
      );
    },
  );

  test(
    'GivenAPreviousScanAndAnUnchangedFile_WhenItIsScannedAgain_ThenItsTagsAreCarriedOverNotReRead',
    () {
      final file = writeFile(
        'a.flac',
        taggedFlac(tags: {'TITLE': 'On disk'}),
      );
      final stat = file.statSync();

      final outcome = scan(
        previous: [
          MusicEntry(
            file: AudioFile(
              path: file.path,
              sizeInBytes: stat.size,
              modifiedAt: stat.modified,
            ),
            // Deliberately not what the file says: if the scan re-read the
            // file, this title would be replaced, and the assertion would see
            // it.
            metadata: const TrackMetadata(title: 'From the catalog'),
          ),
        ],
      );

      expect(outcome.entries.single.title, 'From the catalog');
      expect(outcome.report.reused, 1);
      expect(outcome.report.added, 0);
    },
  );

  test(
    'GivenAFileThatChangedSinceTheLastScan_WhenItIsScannedAgain_ThenItsTagsAreReadAfresh',
    () {
      final file = writeFile('a.flac', taggedFlac(tags: {'TITLE': 'On disk'}));

      final outcome = scan(
        previous: [
          MusicEntry(
            file: AudioFile(
              path: file.path,
              // A size that does not match what is there now.
              sizeInBytes: 1,
              modifiedAt: file.statSync().modified,
            ),
            metadata: const TrackMetadata(title: 'Stale'),
          ),
        ],
      );

      expect(outcome.entries.single.title, 'On disk');
      expect(outcome.report.added, 1);
    },
  );

  test(
    'GivenAFileThatChangedSinceTheLastScan_WhenItIsScannedAgain_ThenNothingIsReportedAsRemoved',
    () {
      // Re-tagging a track is one file added and none removed. Counting
      // removals as "what the catalog held minus what was carried over" made
      // every changed file count as a removal too, so the folders screen told
      // an owner who had corrected one tag that a track had left their
      // library.
      final file = writeFile('a.flac', taggedFlac(tags: {'TITLE': 'On disk'}));

      final outcome = scan(
        previous: [
          MusicEntry(
            file: AudioFile(
              path: file.path,
              sizeInBytes: 1,
              modifiedAt: file.statSync().modified,
            ),
            metadata: const TrackMetadata(title: 'Stale'),
          ),
        ],
      );

      expect(outcome.report.added, 1);
      expect(outcome.report.removed, 0);
    },
  );

  test(
    'GivenAFileTheCatalogHoldsThatIsGoneFromDisk_WhenTheLibraryIsScanned_ThenItIsReportedAsRemoved',
    () {
      final outcome = scan(
        previous: [
          MusicEntry(
            file: AudioFile(
              path: '${root.path}/deleted.flac',
              sizeInBytes: 10,
              modifiedAt: DateTime.utc(2026),
            ),
            metadata: const TrackMetadata(title: 'Gone'),
          ),
        ],
      );

      expect(outcome.entries, isEmpty);
      expect(outcome.report.removed, 1);
    },
  );

  test(
    'GivenARegisteredFolderThatIsNotThere_WhenTheLibraryIsScanned_ThenItIsNamedAndTheRestIsStillScanned',
    () {
      writeTrack('a.flac', {'TITLE': 'Here'});

      final outcome = scanFolders(
        folders: ['${root.path}/nowhere', root.path],
        previous: const [],
        coverDirectory: covers.path,
      );

      expect(outcome.report.tracks, 1);
      expect(outcome.report.unreachableFolders, ['${root.path}/nowhere']);
    },
  );

  test(
    'GivenOneRegisteredFolderInsideAnother_WhenTheLibraryIsScanned_ThenEachTrackIsCollectedOnce',
    () {
      writeTrack('outer/inner/a.flac', {'TITLE': 'Once'});

      final outcome = scanFolders(
        folders: ['${root.path}/outer', '${root.path}/outer/inner'],
        previous: const [],
        coverDirectory: covers.path,
      );

      expect(outcome.report.tracks, 1);
    },
  );

  test(
    'GivenAScanOfManyFiles_WhenItRuns_ThenItReportsTheWalkBeforeTheRead',
    () {
      for (var index = 0; index < 60; index++) {
        writeTrack('$index.flac', {'TITLE': 'Track $index'});
      }

      final reports = <ScanProgress>[];
      scanFolders(
        folders: [root.path],
        previous: const [],
        coverDirectory: covers.path,
        onProgress: reports.add,
      );

      // A total that is still growing cannot be divided into: the walk reports
      // with no fraction, and only the read has one.
      expect(reports.where((report) => report.walking), isNotEmpty);
      expect(
        reports.where((report) => report.walking).every((r) => r.fraction == null),
        isTrue,
      );
      expect(reports.last.walking, isFalse);
      expect(reports.last.fraction, 1.0);
    },
  );

  test(
    'GivenARegisteredFolderThatCannotBeListed_WhenTheLibraryIsScanned_ThenItIsNamedAsUnreachable',
    () {
      // Through IOOverrides rather than a permission bit, because the suite
      // may run as a user every permission bit gives way to.
      writeTrack('locked/a.flac', {'TITLE': 'Behind a door'});
      final locked = p.join(root.path, 'locked');

      final outcome = IOOverrides.runZoned(
        () => scanFolders(
          folders: [locked],
          previous: const [],
          coverDirectory: covers.path,
        ),
        createDirectory: (path) => path == locked
            ? _Unlistable(path)
            : _RealDirectory.of(path),
      );

      expect(outcome.report.unreachableFolders, [locked]);
      expect(outcome.report.tracks, 0);
    },
  );

  test(
    'GivenACatalogReadBackFromDisk_WhenTheLibraryIsScannedInFull_ThenUnchangedFilesAreCarriedOver',
    () async {
      final file = writeFile(
        'a.flac',
        taggedFlac(tags: {'TITLE': 'Airbag'}),
      );
      // The file system keeps a timestamp to the microsecond and the catalog
      // document keeps it to the millisecond. A file whose timestamp happens to
      // fall on a whole millisecond would hide the difference, so make sure
      // this one does not.
      for (var attempt = 0;
          attempt < 20 && file.statSync().modified.microsecond == 0;
          attempt++) {
        file.writeAsBytesSync(file.readAsBytesSync());
      }

      final first = scan();
      final store = JsonCatalogStore(p.join(root.path, '.state'));
      await store.write(
        MusicCatalog(entries: first.entries, scannedAt: first.startedAt),
      );
      final readBack = await store.read();

      final outcome = scan(previous: readBack.entries);

      expect(outcome.report.reused, 1);
      expect(outcome.report.added, 0);
    },
  );

  test(
    'GivenAFolderChangedWhileTheScanWasRunning_WhenTheNextScanWalksCheaply_ThenTheChangeIsRead',
    () {
      writeTrack('a.flac', {'TITLE': 'Airbag'});

      // The change lands after every tag has been read and before the scan
      // hands its outcome back: a tagger writing a new copy and renaming it
      // over the original, which moves the folder's timestamp.
      var changed = false;
      final first = scanFolders(
        folders: [root.path],
        previous: const [],
        coverDirectory: covers.path,
        onProgress: (progress) {
          if (changed || progress.walking) return;
          if (progress.filesRead < progress.filesFound) return;
          changed = true;
          writeFile('a.flac.part', taggedFlac(tags: {'TITLE': 'Retagged'}))
              .renameSync(p.join(root.path, 'a.flac'));
        },
      );
      expect(changed, isTrue);
      expect(first.entries.single.title, 'Airbag');

      final outcome = scan(
        previous: first.entries,
        unchangedSince: first.startedAt,
      );

      expect(outcome.entries.single.title, 'Retagged');
    },
  );

  group('the cheap walk', () {
    /// A moment after everything written so far, which is what a folder's
    /// timestamp is compared against.
    DateTime settledNow() => DateTime.now().add(const Duration(minutes: 1));

    test(
      'GivenAFolderUntouchedSinceTheLastScan_WhenItIsWalkedCheaply_ThenItsTracksAreCarriedOver',
      () {
        writeTrack('a.flac', {'TITLE': 'Airbag'});
        final first = scan();

        final outcome = scan(
          previous: first.entries,
          unchangedSince: settledNow(),
        );

        expect(outcome.report.tracks, 1);
        expect(outcome.report.reused, 1);
        expect(outcome.report.added, 0);
        expect(outcome.entries.single.title, 'Airbag');
      },
    );

    test(
      'GivenATrackRewrittenInPlace_WhenTheFolderIsWalkedCheaply_ThenTheOldTagsAreKept',
      () {
        // The cost of not stat-ing: the file changed, its folder did not, and
        // the cheap walk answers from the catalog. The scan the owner asks for
        // by hand is what picks this up, which is the test below.
        writeTrack('a.flac', {'TITLE': 'Airbag'});
        final first = scan();

        writeTrack('a.flac', {'TITLE': 'Retagged'});

        // Rewriting a file that already exists leaves its folder's own
        // timestamp alone, which is precisely the case the cheap walk cannot
        // see.
        final outcome = scan(
          previous: first.entries,
          unchangedSince: settledNow(),
        );

        expect(outcome.entries.single.title, 'Airbag');
        expect(outcome.report.reused, 1);
      },
    );

    test(
      'GivenATrackRewrittenInPlace_WhenTheFullWalkRuns_ThenItIsReadAgain',
      () {
        writeTrack('a.flac', {'TITLE': 'Airbag'});
        final first = scan();

        writeTrack('a.flac', {'TITLE': 'Retagged'});

        final outcome = scan(previous: first.entries);

        expect(outcome.entries.single.title, 'Retagged');
        expect(outcome.report.added, 1);
      },
    );

    test(
      'GivenATrackTheCatalogDoesNotKnow_WhenItsFolderIsWalkedCheaply_ThenItIsStillRead',
      () {
        // A folder can be settled and still hold a file the last scan never
        // recorded — a scan that was interrupted, or a catalog written before
        // the file arrived. The timestamp is not taken as proof the catalog is
        // complete.
        writeTrack('a.flac', {'TITLE': 'Airbag'});
        final first = scan();

        writeTrack('b.flac', {'TITLE': 'Karma'});

        final outcome = scan(
          previous: first.entries,
          unchangedSince: settledNow(),
        );

        expect(outcome.report.tracks, 2);
        expect(
          [for (final entry in outcome.entries) entry.title],
          ['Airbag', 'Karma'],
        );
      },
    );

    test(
      'GivenAFolderChangedSinceTheLastScan_WhenItIsWalkedCheaply_ThenItIsReadFromDisk',
      () {
        writeTrack('a.flac', {'TITLE': 'Airbag'});
        final first = scan();

        writeTrack('a.flac', {'TITLE': 'Retagged'});

        // The folder itself is newer than the last scan, so nothing about it
        // is taken on trust.
        final outcome = scan(
          previous: first.entries,
          unchangedSince: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(outcome.entries.single.title, 'Retagged');
      },
    );
  });
}

/// The real directory at a path, built outside any [IOOverrides] in force.
abstract final class _RealDirectory {
  static Directory of(String path) =>
      IOOverrides.runWithIOOverrides(() => Directory(path), _NoOverrides());
}

final class _NoOverrides extends IOOverrides {}

/// A directory that is there and refuses to be listed — what a folder this
/// process may not read looks like to the walk.
class _Unlistable implements Directory {
  _Unlistable(this.path) : _real = _RealDirectory.of(path);

  final Directory _real;

  @override
  final String path;

  @override
  bool existsSync() => _real.existsSync();

  @override
  String resolveSymbolicLinksSync() => _real.resolveSymbolicLinksSync();

  @override
  FileStat statSync() => _real.statSync();

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => throw FileSystemException(
    'Directory listing failed',
    path,
    const OSError('Permission denied', 13),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
