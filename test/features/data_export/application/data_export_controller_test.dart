import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/data_export/application/data_export_controller.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// Exporting the owner's data: gathering the sources, building the document off
/// the UI isolate, and offering it to the save dialog.
void main() {
  // Built from local fields, so the date in the suggested name does not depend
  // on the zone the suite happens to run in.
  final now = DateTime(2026, 10, 18, 12);

  final library = [
    entry(id: 'b', title: 'Beta', artist: 'Ann', album: 'First', track: 2),
    entry(id: 'a', title: 'Alpha', artist: 'Ann', album: 'First', track: 1),
    entry(id: 'c', title: 'Gamma', artist: 'Bo'),
  ];

  final playlist = Playlist(
    id: 'p1',
    name: 'Road trip',
    createdAt: DateTime.utc(2026, 1, 2),
    modifiedAt: DateTime.utc(2026, 1, 3),
  );

  final history = PlayHistory(
    tracks: {
      '/library/zzz-a.flac': TrackPlays(
        path: '/library/zzz-a.flac',
        plays: 4,
        lastPlayedAt: DateTime.utc(2026, 10, 10, 12),
      ),
    },
  );

  Harness build({
    List<Playlist> playlists = const [],
    bool failPlaylists = false,
    bool failHistory = false,
  }) {
    final harness = Harness(library: library, playlists: playlists, now: now);
    if (failPlaylists) {
      harness.playlistStore.failRead = const FileSystemException('no access');
    }
    harness.plays.history = history;
    if (failHistory) {
      harness.plays.failRead = const FileSystemException('no access');
    }

    return harness;
  }

  DataExportController exporter(Harness harness) =>
      harness.read(dataExportControllerProvider.notifier);

  Map<String, Object?> savedDocument(Harness harness) =>
      jsonDecode(utf8.decode(harness.fileSaver.saved.single.bytes))
          as Map<String, Object?>;

  List<String> problemSections(Map<String, Object?> document) => [
    for (final problem in document['problems']! as List<Object?>)
      (problem! as Map<String, Object?>)['section']! as String,
  ];

  test('GivenTheLibraryIsStillLoading_WhenTheDataIsExported_ThenItWaitsAndExportsEverySong', () async {
    final harness = build();
    final gate = Completer<void>();
    harness.catalogs.readGate = gate;

    final exporting = exporter(harness).export();
    await pumpEventQueue();
    expect(harness.fileSaver.saved, isEmpty);

    gate.complete();
    final result = await exporting;

    expect(result.outcome, DataExportOutcome.saved);
    final songs = savedDocument(harness)['songs']! as List<Object?>;
    // In the library's own song order: by title.
    expect(
      [for (final song in songs) (song! as Map<String, Object?>)['title']],
      ['Alpha', 'Beta', 'Gamma'],
    );
  });

  test('GivenTheLibraryCannotBeRead_WhenTheDataIsExported_ThenItIsRefusedAndNothingIsOffered', () async {
    final harness = build();
    harness.catalogs.failOnRead = true;

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.libraryFailed);
    expect(result.path, isNull);
    expect(harness.fileSaver.saved, isEmpty);
    expect(harness.read(dataExportControllerProvider), isFalse);
  });

  test('GivenEverythingReadable_WhenTheDataIsExported_ThenItIsSavedWithTheDestination', () async {
    final harness = build(playlists: [playlist]);

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.saved);
    expect(result.path, '/exports/saved');
    final document = savedDocument(harness);
    expect(problemSections(document), isEmpty);
    expect(document['playlists'], hasLength(1));
    expect(document['playHistory'], hasLength(1));
    expect(document['exportedAt'], now.toUtc().toIso8601String());
    expect(document['orpheusVersion'], '1.0.0');
  });

  test('GivenThePlaylistsCannotBeRead_WhenTheDataIsExported_ThenTheyAreEmptyAndTheDocumentSaysSo', () async {
    final harness = build(failPlaylists: true);

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    expect(result.path, '/exports/saved');
    final document = savedDocument(harness);
    expect(document['playlists'], isEmpty);
    expect(problemSections(document), ['playlists']);
    // The sources that could be read are all there.
    expect(document['songs'], hasLength(3));
    expect(document['playHistory'], hasLength(1));
  });

  test('GivenThePlayHistoryCannotBeRead_WhenTheDataIsExported_ThenItIsEmptyAndTheDocumentSaysSo', () async {
    final harness = build(failHistory: true);

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    final document = savedDocument(harness);
    expect(document['playHistory'], isEmpty);
    expect(problemSections(document), ['playHistory']);
    expect(document['songs'], hasLength(3));
  });

  test('GivenNeitherPlaylistsNorHistoryCanBeRead_WhenTheDataIsExported_ThenBothAreReported', () async {
    final harness = build(failPlaylists: true, failHistory: true);

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    expect(problemSections(savedDocument(harness)), [
      'playlists',
      'playHistory',
    ]);
  });

  test('GivenTheClockIsOnTheEighteenth_WhenTheDataIsExported_ThenTheSuggestedNameCarriesThatDate', () async {
    final harness = build();

    await exporter(harness).export();

    expect(
      harness.fileSaver.saved.single.suggestedName,
      'orpheus-data-2026-10-18.json',
    );
  });

  test('GivenASingleDigitMonthAndDay_WhenTheDataIsExported_ThenTheDateIsZeroPadded', () async {
    final harness = Harness(library: library, now: DateTime(2027, 3, 4, 9));

    await exporter(harness).export();

    expect(
      harness.fileSaver.saved.single.suggestedName,
      'orpheus-data-2027-03-04.json',
    );
  });

  test(
    'GivenTheDocumentIsBuilt_WhenItIsSaved_ThenTheBytesAreTheEncodedDocument',
    () async {
      final harness = build(playlists: [playlist]);
      final catalog = await harness.library();

      await exporter(harness).export();

      final expected = encodeDataExport(
        buildDataExport(
          ExportSources(
            songs: songsIn(catalog.entries),
            playlists: [playlist],
            history: history,
            now: now,
            orpheusVersion: '1.0.0',
          ),
        ),
      );
      final saved = harness.fileSaver.saved.single.bytes;
      expect(saved, expected);
      expect(utf8.decode(saved), endsWith('}\n'));
    },
  );

  test(
    'GivenTheOwnerCancelsTheDialog_WhenTheDataIsExported_ThenItIsCancelled',
    () async {
      final harness = build();
      harness.fileSaver.next = null;

      final result = await exporter(harness).export();

      expect(result.outcome, DataExportOutcome.cancelled);
      expect(result.path, isNull);
      expect(harness.read(dataExportControllerProvider), isFalse);
    },
  );

  test('GivenThePlatformSavesWithoutAPath_WhenTheDataIsExported_ThenItIsSavedWithNoPath', () async {
    final harness = build();
    harness.fileSaver.next = const SavedFile();

    final result = await exporter(harness).export();

    expect(result.outcome, DataExportOutcome.saved);
    expect(result.path, isNull);
  });

  test(
    'GivenTheSaverThrows_WhenTheDataIsExported_ThenItFailsAndCanBeTriedAgain',
    () async {
      final harness = build();
      harness.fileSaver.failure = const FileSystemException('disk full');

      final failed = await exporter(harness).export();

      expect(failed.outcome, DataExportOutcome.failed);
      expect(harness.read(dataExportControllerProvider), isFalse);

      harness.fileSaver.failure = null;
      final retried = await exporter(harness).export();

      expect(retried.outcome, DataExportOutcome.saved);
    },
  );

  test('GivenAnExportIsRunning_WhenAnotherIsAsked_ThenItIsIgnoredAndTheFileIsOfferedOnce', () async {
    final harness = build();
    final gate = Completer<void>();
    harness.catalogs.readGate = gate;

    final first = exporter(harness).export();
    await pumpEventQueue();
    expect(harness.read(dataExportControllerProvider), isTrue);

    final second = exporter(harness).export();
    gate.complete();
    await Future.wait([first, second]);

    expect(harness.fileSaver.saved, hasLength(1));
    expect(harness.read(dataExportControllerProvider), isFalse);
  });

  test('GivenNothingIsRunning_WhenTheStateIsRead_ThenItIsNotExporting', () {
    final harness = build();

    expect(harness.read(dataExportControllerProvider), isFalse);
  });

  group('the encoder', () {
    final sources = ExportSources(
      songs: library,
      playlists: const [],
      history: PlayHistory.empty,
      now: DateTime.utc(2026, 10, 18),
      orpheusVersion: '1.0.0',
    );

    test(
      'GivenARunner_WhenTheDocumentIsEncoded_ThenTheWorkIsHandedToItOnce',
      () async {
        var runs = 0;
        Future<R> runner<R>(FutureOr<R> Function() computation) async {
          runs++;

          return computation();
        }

        final bytes = await encodeOffTheUiIsolate(sources, run: runner);

        expect(runs, 1);
        expect(bytes, encodeDataExport(buildDataExport(sources)));
      },
    );

    test('GivenTheDefaultRunner_WhenTheDocumentIsEncoded_ThenItCrossesARealIsolateIntact', () async {
      final bytes = await encodeOffTheUiIsolate(sources);

      expect(bytes, encodeDataExport(buildDataExport(sources)));
    });
  });
}
