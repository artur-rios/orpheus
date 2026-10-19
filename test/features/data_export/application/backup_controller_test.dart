import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/data_export/application/backup_controller.dart';
import 'package:orpheus/features/data_export/application/data_export_controller.dart';
import 'package:orpheus/features/data_export/data/zip_backup_codec.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// Backing Orpheus up: gathering what the JSON export gathers, the playlists'
/// covers and the preferences, building the ZIP off the UI isolate, and
/// offering it to the save dialog.
void main() {
  // Built from local fields, so the date in the suggested name does not depend
  // on the zone the suite happens to run in.
  final now = DateTime(2026, 10, 18, 12);

  final library = [
    entry(id: 'a', title: 'Alpha', artist: 'Ann', album: 'First', track: 1),
    entry(id: 'b', title: 'Beta', artist: 'Ann', album: 'First', track: 2),
  ];

  Playlist playlist(String id, {String? coverId}) => Playlist(
    id: id,
    name: 'Playlist $id',
    createdAt: DateTime.utc(2026, 1, 2),
    modifiedAt: DateTime.utc(2026, 1, 3),
    coverId: coverId,
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

  final coverBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 4]);

  Harness build({
    List<Playlist> playlists = const [],
    bool failPlaylists = false,
    bool failHistory = false,
    InMemorySettingsStore? settings,
  }) {
    final harness = Harness(
      library: library,
      playlists: playlists,
      now: now,
      settings: settings,
    );
    if (failPlaylists) {
      harness.playlistStore.failRead = const FileSystemException('no access');
    }
    harness.plays.history = history;
    if (failHistory) {
      harness.plays.failRead = const FileSystemException('no access');
    }

    return harness;
  }

  BackupController backer(Harness harness) =>
      harness.read(backupControllerProvider.notifier);

  BackupContents savedBackup(Harness harness) =>
      readBackup(harness.fileSaver.saved.single.bytes);

  test('GivenEverythingReadable_WhenOrpheusIsBackedUp_ThenTheZipIsSavedWithTheDestination', () async {
    final harness = build(playlists: [playlist('p1')]);

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.saved);
    expect(result.path, '/exports/saved');
    final backup = savedBackup(harness);
    expect(backup.isFullBackup, isTrue);
    expect(backup.data['songs'], hasLength(2));
    expect(backup.data['playlists'], hasLength(1));
    expect(backup.data['playHistory'], hasLength(1));
    expect(backup.data['problems'], isEmpty);
    expect(backup.createdAt, now.toUtc());
    expect(backup.preferences, isNotNull);
  });

  test('GivenPlaylistsWithAndWithoutACustomCover_WhenOrpheusIsBackedUp_ThenOnlyTheCustomCoversAreInTheZip', () async {
    final harness = build(
      playlists: [
        playlist('p1'),
        playlist('p2', coverId: 'cover-2'),
      ],
    );
    harness.playlistCovers.covers['p2'] = coverBytes;
    // A cover left behind by a playlist that no longer has one is not saved.
    harness.playlistCovers.covers['p1'] = Uint8List.fromList([9]);

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.saved);
    expect(savedBackup(harness).covers, {'p2': coverBytes});
  });

  test('GivenAPlaylistWhoseCoverFileIsGone_WhenOrpheusIsBackedUp_ThenItIsSavedWithoutItAndNothingIsReported', () async {
    final harness = build(playlists: [playlist('p2', coverId: 'cover-2')]);

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.saved);
    expect(savedBackup(harness).covers, isEmpty);
  });

  test('GivenACoverThatCannotBeRead_WhenOrpheusIsBackedUp_ThenTheRestIsSavedAndItIsPartial', () async {
    final harness = build(
      playlists: [
        playlist('p2', coverId: 'cover-2'),
        playlist('p3', coverId: 'cover-3'),
      ],
    );
    harness.playlistCovers.covers['p2'] = coverBytes;
    harness.playlistCovers.covers['p3'] = coverBytes;
    harness.playlistCovers.unreadable.add('p2');

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    expect(savedBackup(harness).covers, {'p3': coverBytes});
  });

  test('GivenThePreferencesTheOwnerSet_WhenOrpheusIsBackedUp_ThenTheZipCarriesThemAsTheSettingsStoreWritesThem', () async {
    final settings = InMemorySettingsStore(
      themeMode: ThemeMode.dark,
      locale: const Locale('pt', 'BR'),
      libraryFolders: [r'D:\Music', '/home/ann/Music'],
      opensPlayerOnPlay: false,
      rescansAtStartup: false,
      fetchesLyricsOnline: false,
      checksForUpdatesOnStartup: false,
      showsAutoPlaylists: false,
      skippedUpdateVersion: '9.9.9',
    );
    await settings.setVolume(0.25);
    final harness = build(settings: settings);

    await backer(harness).backup();

    expect(
      savedBackup(harness).preferences,
      const PreferencesSnapshot(
        themeMode: 'dark',
        locale: 'pt_BR',
        opensPlayerOnPlay: false,
        rescansAtStartup: false,
        fetchesLyricsOnline: false,
        checksForUpdatesOnStartup: false,
        showsAutoPlaylists: false,
        volume: 0.25,
        libraryFolders: [r'D:\Music', '/home/ann/Music'],
      ),
    );
  });

  test('GivenALanguageWithNoCountryAndOneFollowingTheSystem_WhenOrpheusIsBackedUp_ThenTheTagIsTheLanguageOrNull', () async {
    final english = build(
      settings: InMemorySettingsStore(locale: const Locale('en')),
    );
    final system = build();

    await backer(english).backup();
    await backer(system).backup();

    expect(savedBackup(english).preferences!.locale, 'en');
    expect(savedBackup(system).preferences!.locale, isNull);
  });

  test('GivenThePlaylistsCannotBeRead_WhenOrpheusIsBackedUp_ThenItIsSavedAsPartialAndTheDataSaysSo', () async {
    final harness = build(failPlaylists: true);

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    expect(result.path, '/exports/saved');
    final backup = savedBackup(harness);
    expect(backup.data['playlists'], isEmpty);
    final problems = (backup.data['problems']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect([for (final p in problems) p['section']], ['playlists']);
    expect(backup.data['songs'], hasLength(2));
  });

  test('GivenThePlayHistoryCannotBeRead_WhenOrpheusIsBackedUp_ThenItIsSavedAsPartial', () async {
    final harness = build(failHistory: true);

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.savedWithProblems);
    expect(savedBackup(harness).data['playHistory'], isEmpty);
  });

  test(
    'GivenTheLibraryCannotBeRead_WhenOrpheusIsBackedUp_ThenNothingIsOffered',
    () async {
      final harness = build();
      harness.catalogs.failOnRead = true;

      final result = await backer(harness).backup();

      expect(result.outcome, DataExportOutcome.libraryFailed);
      expect(harness.fileSaver.saved, isEmpty);
      expect(harness.read(backupControllerProvider), isFalse);
    },
  );

  test(
    'GivenTheLibraryIsBeingRebuilt_WhenOrpheusIsBackedUp_ThenItIsPartial',
    () async {
      final harness = build();
      harness.catalogs.seed(MusicCatalog(entries: const [], isStale: true));

      final result = await backer(harness).backup();

      expect(result.outcome, DataExportOutcome.savedWithProblems);
    },
  );

  test('GivenTheClockIsOnTheEighteenth_WhenOrpheusIsBackedUp_ThenTheSuggestedNameCarriesThatDate', () async {
    final harness = build();

    await backer(harness).backup();

    expect(
      harness.fileSaver.saved.single.suggestedName,
      'orpheus-backup-2026-10-18.zip',
    );
  });

  test('GivenASingleDigitMonthAndDay_WhenOrpheusIsBackedUp_ThenTheDateIsZeroPadded', () async {
    final harness = Harness(library: library, now: DateTime(2027, 3, 4, 9));

    await backer(harness).backup();

    expect(
      harness.fileSaver.saved.single.suggestedName,
      'orpheus-backup-2027-03-04.zip',
    );
  });

  test(
    'GivenTheOwnerCancelsTheDialog_WhenOrpheusIsBackedUp_ThenItIsCancelled',
    () async {
      final harness = build();
      harness.fileSaver.next = null;

      final result = await backer(harness).backup();

      expect(result.outcome, DataExportOutcome.cancelled);
      expect(result.path, isNull);
      expect(harness.read(backupControllerProvider), isFalse);
    },
  );

  test('GivenThePlatformSavesWithoutAPath_WhenOrpheusIsBackedUp_ThenItIsSavedWithNoPath', () async {
    final harness = build();
    harness.fileSaver.next = const SavedFile();

    final result = await backer(harness).backup();

    expect(result.outcome, DataExportOutcome.saved);
    expect(result.path, isNull);
  });

  test(
    'GivenTheSaverThrows_WhenOrpheusIsBackedUp_ThenItFailsAndCanBeTriedAgain',
    () async {
      final harness = build();
      harness.fileSaver.failure = const FileSystemException('disk full');

      final failed = await backer(harness).backup();

      expect(failed.outcome, DataExportOutcome.failed);
      expect(harness.read(backupControllerProvider), isFalse);

      harness.fileSaver.failure = null;
      final retried = await backer(harness).backup();

      expect(retried.outcome, DataExportOutcome.saved);
    },
  );

  test('GivenABackupIsRunning_WhenAnotherIsAsked_ThenItIsIgnoredAndTheFileIsOfferedOnce', () async {
    final harness = build();
    final gate = Completer<void>();
    harness.catalogs.readGate = gate;

    final first = backer(harness).backup();
    await pumpEventQueue();
    expect(harness.read(backupControllerProvider), isTrue);

    final second = backer(harness).backup();
    gate.complete();
    await Future.wait([first, second]);

    expect(harness.fileSaver.saved, hasLength(1));
    expect(harness.read(backupControllerProvider), isFalse);
  });

  test('GivenNothingIsRunning_WhenTheStateIsRead_ThenItIsNotBackingUp', () {
    expect(build().read(backupControllerProvider), isFalse);
  });

  test('GivenABackupAndAnExport_WhenBothAreMade_ThenTheZipHoldsTheDocumentTheJsonExportWrites', () async {
    final harness = build(playlists: [playlist('p1')]);

    await harness.read(dataExportControllerProvider.notifier).export();
    await backer(harness).backup();

    final json = harness.fileSaver.saved.first.bytes;
    final zip = harness.fileSaver.saved.last.bytes;
    expect(
      jsonEncode(readBackup(zip).data),
      jsonEncode(jsonDecode(utf8.decode(json))),
    );
  });

  group('the encoder', () {
    final sources = BackupSources(
      export: ExportSources(
        songs: library,
        playlists: const [],
        history: PlayHistory.empty,
        now: DateTime.utc(2026, 10, 18),
        orpheusVersion: '1.0.0',
      ),
      preferences: const PreferencesSnapshot(
        themeMode: 'system',
        locale: null,
        opensPlayerOnPlay: true,
        rescansAtStartup: true,
        fetchesLyricsOnline: true,
        checksForUpdatesOnStartup: true,
        showsAutoPlaylists: true,
        volume: 1,
        libraryFolders: [],
      ),
      covers: {
        'p1': Uint8List.fromList([7, 8]),
      },
    );

    Uint8List expected() => encodeBackupZip(
      data: buildDataExport(sources.export),
      preferences: sources.preferences,
      covers: sources.covers,
      createdAt: sources.export.now,
      orpheusVersion: '1.0.0',
    );

    test(
      'GivenARunner_WhenTheBackupIsEncoded_ThenTheWorkIsHandedToItOnce',
      () async {
        var runs = 0;
        Future<R> runner<R>(FutureOr<R> Function() computation) async {
          runs++;

          return computation();
        }

        final bytes = await encodeBackupOffTheUiIsolate(sources, run: runner);

        expect(runs, 1);
        expect(bytes, expected());
      },
    );

    test('GivenTheDefaultRunner_WhenTheBackupIsEncoded_ThenItCrossesARealIsolateIntact', () async {
      final bytes = await encodeBackupOffTheUiIsolate(sources);

      expect(bytes, expected());
    });
  });
}
