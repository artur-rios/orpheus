import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/data_export/application/restore_controller.dart';
import 'package:orpheus/features/data_export/data/zip_backup_codec.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/data_export/domain/restore_plan.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Restoring Orpheus from a backup ZIP or a data JSON: reading the file, the
/// music folders, the choices, and writing each part whole or not at all.
void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  final made = DateTime.utc(2026, 10, 1, 9);

  final songA = entry(id: 'a', title: 'Alpha', artist: 'Ann', album: 'One');
  final songB = entry(id: 'b', title: 'Beta', artist: 'Ann', album: 'One');
  final library = [songA, songB];

  final picture = Uint8List.fromList([4, 2]);

  PlaylistEntry entryOf(String id, MusicEntry song) =>
      PlaylistEntry(id: id, path: song.file.path, title: song.title);

  Playlist playlist(
    String id,
    String name,
    List<MusicEntry> songs, {
    String? coverId,
  }) => Playlist(
    id: id,
    name: name,
    entries: [
      for (final (index, song) in songs.indexed) entryOf('$id-$index', song),
    ],
    coverId: coverId,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026, 2),
  );

  TrackPlays plays(MusicEntry song, int count) => TrackPlays(
    path: song.file.path,
    plays: count,
    lastPlayedAt: DateTime.utc(2026, 9, count),
  );

  PlayHistory historyOf(List<TrackPlays> tracks) =>
      PlayHistory(tracks: {for (final track in tracks) track.path: track});

  const backupPreferences = PreferencesSnapshot(
    themeMode: 'light',
    locale: 'pt_BR',
    opensPlayerOnPlay: false,
    rescansAtStartup: true,
    fetchesLyricsOnline: true,
    checksForUpdatesOnStartup: true,
    showsAutoPlaylists: true,
    volume: 0.5,
    libraryFolders: ['/music'],
  );

  // What the backup holds unless a test says otherwise: a playlist sharing a
  // name with the owner's, one that is new, and plays of both songs.
  final backupPlaylists = [
    playlist('b1', 'Mine', [songA, songB]),
    playlist('b2', 'Theirs', [songB], coverId: 'b2'),
  ];
  final backupHistory = historyOf([plays(songA, 2), plays(songB, 4)]);

  Map<String, Object?> dataOf({
    List<MusicEntry>? songs,
    List<Playlist>? playlists,
    PlayHistory? history,
    List<ExportProblem> problems = const [],
  }) => buildDataExport(
    ExportSources(
      songs: songs ?? library,
      playlists: playlists ?? backupPlaylists,
      history: history ?? backupHistory,
      now: made,
      problems: problems,
    ),
  );

  Uint8List zip({
    List<MusicEntry>? songs,
    List<Playlist>? playlists,
    PlayHistory? history,
    List<ExportProblem> problems = const [],
    PreferencesSnapshot preferences = backupPreferences,
    Map<String, Uint8List>? covers,
  }) => encodeBackupZip(
    data: dataOf(
      songs: songs,
      playlists: playlists,
      history: history,
      problems: problems,
    ),
    preferences: preferences,
    covers: covers ?? {'b2': picture},
    createdAt: made,
  );

  Uint8List json() => encodeDataExport(dataOf());

  // The owner's own data: a playlist called as one of the backup's, plays of
  // one song, and a theme they chose.
  final ownPlaylist = playlist('m', 'Mine', [songA], coverId: 'm');
  final ownHistory = historyOf([plays(songA, 5)]);

  Harness build({
    List<MusicEntry> device = const [],
    bool deviceLibrary = true,
    List<Playlist>? playlists,
    PlayHistory? history,
    List<String> folders = const ['/music'],
    Set<String> existing = const {'/music'},
    List<MusicEntry>? scanned,
    InMemorySettingsStore? settings,
  }) {
    final harness = Harness(
      library: deviceLibrary ? [...library, ...device] : const [],
      playlists: playlists ?? [ownPlaylist],
      now: now,
      existingFolders: {...existing},
      settings:
          settings ??
          InMemorySettingsStore(
            themeMode: ThemeMode.dark,
            libraryFolders: folders,
          ),
      scanner: ScriptedScanner([
        ScanCompleted(
          catalog: MusicCatalog(
            entries: albumArtistsAcross(scanned ?? library),
            scannedAt: now,
          ),
          report: ScanReport(
            tracks: (scanned ?? library).length,
            added: 1,
            removed: 0,
            reused: 0,
          ),
        ),
      ]),
    );
    harness.playlistCovers.covers['m'] = Uint8List.fromList([1]);
    harness.plays.history = history ?? ownHistory;

    return harness;
  }

  RestoreController restorer(Harness harness) =>
      harness.read(restoreControllerProvider.notifier);

  RestoreState stateOf(Harness harness) =>
      harness.read(restoreControllerProvider);

  ScriptedScanner scannerOf(Harness harness) =>
      harness.read(libraryScannerProvider) as ScriptedScanner;

  /// Picks [bytes] and, for a ZIP, continues past the folders unchanged.
  Future<RestoreController> atChoices(Harness harness, Uint8List bytes) async {
    harness.fileOpener.next = bytes;
    final controller = restorer(harness);
    await controller.pick();
    if (stateOf(harness).stage == RestoreStage.folders) {
      await controller.continueToChoices();
    }
    expect(stateOf(harness).stage, RestoreStage.choices);

    return controller;
  }

  void expectNothingWritten(Harness harness) {
    expect(harness.playlistStore.writes, 0);
    expect(harness.playlistCovers.deleted, isEmpty);
    expect(harness.plays.writes, 0);
    expect(harness.settings.themeMode, ThemeMode.dark);
    expect(harness.settings.opensPlayerOnPlay, isTrue);
  }

  List<String> namesIn(Harness harness) => [
    for (final playlist in harness.playlistStore.playlists) playlist.name,
  ];

  group('reading the file', () {
    test(
      'GivenABackupZip_WhenPicked_ThenTheFoldersAreShownWithWhetherEachIsHere',
      () async {
        final harness = build(existing: {'/music'});
        harness.fileOpener.next = zip(
          preferences: const PreferencesSnapshot(
            themeMode: 'light',
            locale: null,
            opensPlayerOnPlay: true,
            rescansAtStartup: true,
            fetchesLyricsOnline: true,
            checksForUpdatesOnStartup: true,
            showsAutoPlaylists: true,
            volume: 1,
            libraryFolders: ['/old/Music', '/music'],
          ),
        );

        await restorer(harness).pick();

        final state = stateOf(harness);
        expect(state.stage, RestoreStage.folders);
        expect(
          [
            for (final folder in state.backupFolders)
              (folder.path, folder.found),
          ],
          [('/old/Music', false), ('/music', true)],
        );
        expect(state.deviceFolders, ['/music']);
        expect(harness.fileOpener.requests, [
          ['zip', 'json'],
        ]);
      },
    );

    test(
      'GivenABackupZip_WhenPicked_ThenWhatItHoldsIsShownAndNothingIsWritten',
      () async {
        final harness = build();
        harness.fileOpener.next = zip();

        await restorer(harness).pick();

        final overview = stateOf(harness).overview!;
        expect(overview.isFullBackup, isTrue);
        expect(overview.createdAt, made);
        expect(overview.playlists, 2);
        expect(overview.songsWithPlays, 2);
        expect(overview.covers, 1);
        expect(overview.hasPreferences, isTrue);
        expectNothingWritten(harness);
        expect(scannerOf(harness).requests, isEmpty);
        expect(harness.settings.libraryFolders, ['/music']);
      },
    );

    test(
      'GivenADataJson_WhenPicked_ThenTheChoicesAreShownWithPreferencesDisabled',
      () async {
        final harness = build();
        harness.fileOpener.next = json();

        await restorer(harness).pick();

        final state = stateOf(harness);
        expect(state.stage, RestoreStage.choices);
        expect(state.overview!.isFullBackup, isFalse);
        expect(state.overview!.hasPreferences, isFalse);
        expect(state.disabled, {
          RestorePart.preferences: RestoreRefusal.notInFile,
        });
        expect(scannerOf(harness).requests, isEmpty);
        expectNothingWritten(harness);
      },
    );

    test(
      'GivenAFileThatIsNotABackup_WhenPicked_ThenItFailsAndNothingIsWritten',
      () async {
        final harness = build();
        harness.fileOpener.next = Uint8List.fromList(utf8.encode('hello'));

        await restorer(harness).pick();

        final state = stateOf(harness);
        expect(state.stage, RestoreStage.failed);
        expect(state.failure, isA<NotABackup>());
        expectNothingWritten(harness);
      },
    );

    test(
      'GivenABackupFromANewerOrpheus_WhenPicked_ThenItFailsSayingWhichVersion',
      () async {
        final harness = build();
        harness.fileOpener.next = Uint8List.fromList(
          utf8.encode(
            jsonEncode({'format': 'orpheus-data', 'formatVersion': 9}),
          ),
        );

        await restorer(harness).pick();

        final state = stateOf(harness);
        expect(state.stage, RestoreStage.failed);
        expect(state.failure, isA<NewerBackupVersion>());
        expect((state.failure! as NewerBackupVersion).version, 9);
        expectNothingWritten(harness);
      },
    );

    test(
      'GivenAFileThatCannotBeRead_WhenPicked_ThenItFailsAsNotABackup',
      () async {
        final harness = build();
        harness.fileOpener.failure = const FileSystemException('locked');

        await restorer(harness).pick();

        expect(stateOf(harness).stage, RestoreStage.failed);
        expect(stateOf(harness).failure, isA<NotABackup>());
      },
    );

    test('GivenTheDialogIsCancelled_WhenPicking_ThenNothingHappens', () async {
      final harness = build();

      await restorer(harness).pick();

      expect(stateOf(harness).stage, RestoreStage.idle);
      expectNothingWritten(harness);
    });
  });

  group('the music folders', () {
    test(
      'GivenFoldersChosen_WhenContinuing_ThenTheyBecomeTheWholeSetAndAScanRuns',
      () async {
        final harness = build(folders: ['/music', '/other']);
        harness.fileOpener.next = zip();
        final controller = restorer(harness);
        await controller.pick();

        controller.chooseFolders(['/new']);
        // Staged, not written.
        expect(harness.settings.libraryFolders, ['/music', '/other']);
        await controller.continueToChoices();

        expect(harness.read(libraryFoldersControllerProvider), ['/new']);
        expect(harness.settings.libraryFolders, ['/new']);
        expect(scannerOf(harness).requests, [
          ['/new'],
        ]);
        final state = stateOf(harness);
        expect(state.stage, RestoreStage.choices);
        expect(state.foldersChanged, isTrue);
      },
    );

    test(
      'GivenADeviceWithNoFolders_WhenAZipIsPicked_ThenTheBackupFoldersThatExistHereAreStaged',
      () async {
        final harness = build(
          folders: const [],
          existing: {'/music'},
          deviceLibrary: false,
        );
        harness.fileOpener.next = zip(
          preferences: const PreferencesSnapshot(
            themeMode: 'light',
            locale: null,
            opensPlayerOnPlay: true,
            rescansAtStartup: true,
            fetchesLyricsOnline: true,
            checksForUpdatesOnStartup: true,
            showsAutoPlaylists: true,
            volume: 1,
            libraryFolders: ['/old/Music', '/music'],
          ),
        );
        final controller = restorer(harness);

        await controller.pick();

        expect(stateOf(harness).stagedFolders, ['/music']);
        // Staged, not written.
        expect(harness.settings.libraryFolders, isEmpty);

        await controller.continueToChoices();

        expect(harness.read(libraryFoldersControllerProvider), ['/music']);
        expect(scannerOf(harness).requests, [
          ['/music'],
        ]);
      },
    );

    test(
      'GivenADeviceWithFolders_WhenAZipIsPicked_ThenNothingIsStaged',
      () async {
        final harness = build(existing: {'/music'});
        harness.fileOpener.next = zip();

        await restorer(harness).pick();

        expect(stateOf(harness).stagedFolders, isNull);
      },
    );

    test(
      'GivenADeviceWithNoFoldersAndNoneOfTheBackupsHere_WhenAZipIsPicked_ThenNothingIsStaged',
      () async {
        final harness = build(folders: const [], existing: const {});
        harness.fileOpener.next = zip();

        await restorer(harness).pick();

        expect(stateOf(harness).stagedFolders, isNull);
      },
    );

    test('GivenNoFoldersChosenAndALibrary_WhenContinuing_ThenItMovesOnWithoutAScan', () async {
      final harness = build();
      harness.fileOpener.next = zip();
      final controller = restorer(harness);
      await controller.pick();

      await controller.continueToChoices();

      expect(stateOf(harness).stage, RestoreStage.choices);
      expect(stateOf(harness).foldersChanged, isFalse);
      expect(scannerOf(harness).requests, isEmpty);
    });

    test(
      'GivenNoFoldersChosenAndAnEmptyLibrary_WhenContinuing_ThenItScansFirst',
      () async {
        final harness = build(deviceLibrary: false);
        harness.fileOpener.next = zip();
        final controller = restorer(harness);
        await controller.pick();

        await controller.continueToChoices();

        expect(scannerOf(harness).requests, [
          ['/music'],
        ]);
        expect(stateOf(harness).stage, RestoreStage.choices);
      },
    );

    test('GivenOneFolderOnEachSide_WhenRestored_ThenPlaysUnderTheOldFolderGoToTheNew', () async {
      final old = entry(id: 'z', directory: '/old/Music');
      final here = entry(id: 'z', directory: '/music');
      final harness = build(device: [here], history: PlayHistory.empty);
      final controller = await atChoices(
        harness,
        zip(
          songs: [old],
          playlists: const [],
          history: historyOf([plays(old, 3)]),
          preferences: const PreferencesSnapshot(
            themeMode: 'system',
            locale: null,
            opensPlayerOnPlay: true,
            rescansAtStartup: true,
            fetchesLyricsOnline: true,
            checksForUpdatesOnStartup: true,
            showsAutoPlaylists: true,
            volume: 1,
            libraryFolders: ['/old/Music'],
          ),
        ),
      );

      await controller.restore();

      expect(harness.plays.history.tracks.keys, [here.file.path]);
      expect(harness.plays.history.tracks[here.file.path]!.plays, 3);
    });

    test(
      'GivenTwoFoldersOnThisDevice_WhenRestored_ThenNoPathIsMoved',
      () async {
        final old = entry(id: 'z', directory: '/old/Music');
        final here = entry(id: 'z', directory: '/music');
        final harness = build(
          device: [here],
          history: PlayHistory.empty,
          folders: ['/music', '/more'],
        );
        final controller = await atChoices(
          harness,
          zip(
            songs: [old],
            playlists: const [],
            history: historyOf([plays(old, 3)]),
            preferences: const PreferencesSnapshot(
              themeMode: 'system',
              locale: null,
              opensPlayerOnPlay: true,
              rescansAtStartup: true,
              fetchesLyricsOnline: true,
              checksForUpdatesOnStartup: true,
              showsAutoPlaylists: true,
              volume: 1,
              libraryFolders: ['/old/Music'],
            ),
          ),
        );

        await controller.restore();

        expect(harness.plays.history.tracks.keys, [old.file.path]);
      },
    );
  });

  group('the choices', () {
    test('GivenABackup_WhenTheChoicesAreShown_ThenEveryPartIsMerge', () async {
      final harness = build();

      await atChoices(harness, zip());

      final state = stateOf(harness);
      expect(state.choices, {
        RestorePart.playlists: RestoreChoice.merge,
        RestorePart.history: RestoreChoice.merge,
        RestorePart.preferences: RestoreChoice.merge,
      });
      expect(state.disabled, isEmpty);
      expect(state.playlistsHere, 1);
      expect(state.songsWithPlaysHere, 1);
    });

    test(
      'GivenTheDefaults_WhenRestoredOntoExistingData_ThenNothingHereIsLost',
      () async {
        final harness = build();
        final controller = await atChoices(harness, zip());

        final summary = await controller.restore();

        // The owner's playlist keeps its id and gains the backup's song.
        final mine = harness.playlistStore.playlists.firstWhere(
          (playlist) => playlist.name == 'Mine',
        );
        expect(mine.id, 'm');
        expect(
          [for (final e in mine.entries) e.path],
          [songA.file.path, songB.file.path],
        );
        expect(namesIn(harness), ['Mine', 'Theirs']);
        // The higher count of each song.
        expect(harness.plays.history.tracks[songA.file.path]!.plays, 5);
        expect(harness.plays.history.tracks[songB.file.path]!.plays, 4);
        // The theme the owner chose stays; what they left at its default
        // takes the backup's.
        expect(harness.settings.themeMode, ThemeMode.dark);
        expect(harness.settings.opensPlayerOnPlay, isFalse);
        expect(harness.settings.locale, const Locale('pt', 'BR'));
        expect(harness.settings.volume, 0.5);

        expect(summary.playlists, isA<PlaylistsRestored>());
        final playlists = summary.playlists as PlaylistsRestored;
        expect(
          (playlists.added, playlists.merged, playlists.replaced),
          (1, 1, 0),
        );
        final history = summary.history as HistoryRestored;
        expect((history.songs, history.notInLibrary), (2, 0));
        expect((summary.preferences as PreferencesRestored).changed, isTrue);
        expect(summary.coverFailures, isEmpty);
        expect(stateOf(harness).stage, RestoreStage.done);
        expect(stateOf(harness).summary, same(summary));
      },
    );

    test('GivenTheDefaults_WhenRestored_ThenEachPartIsWrittenOnce', () async {
      final harness = build();
      final controller = await atChoices(harness, zip());

      await controller.restore();

      expect(harness.playlistStore.writes, 1);
      expect(harness.plays.writes, 1);
    });

    test('GivenReplaceForEveryPart_WhenRestored_ThenTheBackupTakesThePlaceOfWhatIsHere', () async {
      final harness = build();
      final controller = await atChoices(harness, zip());
      for (final part in RestorePart.values) {
        controller.choose(part, RestoreChoice.replace);
      }

      final summary = await controller.restore();

      expect(namesIn(harness), ['Mine', 'Theirs']);
      expect(harness.playlistStore.playlists.any((p) => p.id == 'm'), isFalse);
      // The owner's old cover goes with their playlist; the backup's comes
      // in under the new playlist's id.
      expect(harness.playlistCovers.deleted, ['m']);
      final theirs = harness.playlistStore.playlists.last;
      expect(harness.playlistCovers.covers[theirs.id], picture);
      expect(harness.plays.history.tracks[songA.file.path]!.plays, 2);
      expect(harness.plays.history.tracks[songB.file.path]!.plays, 4);
      expect(harness.settings.themeMode, ThemeMode.light);
      expect(harness.settings.volume, 0.5);
      expect(harness.settings.libraryFolders, ['/music']);
      expect((summary.playlists as PlaylistsRestored).replaced, 1);
    });

    test('GivenSkipForEveryPart_WhenRestored_ThenWhatIsHereIsKeptAndOnlyTheNewIsAdded', () async {
      final harness = build();
      final controller = await atChoices(harness, zip());
      for (final part in RestorePart.values) {
        controller.choose(part, RestoreChoice.skip);
      }

      final summary = await controller.restore();

      final mine = harness.playlistStore.playlists.first;
      expect(mine, ownPlaylist);
      expect(namesIn(harness), ['Mine', 'Theirs']);
      expect(harness.plays.history.tracks[songA.file.path]!.plays, 5);
      expect(harness.plays.history.tracks[songB.file.path]!.plays, 4);
      expect(harness.settings.themeMode, ThemeMode.dark);
      expect(harness.settings.opensPlayerOnPlay, isTrue);
      expect((summary.preferences as PreferencesRestored).changed, isFalse);
    });

    test('GivenAPartTheBackupCouldNotRead_WhenRestoredWithReplace_ThenItIsDisabledAndNeverWritten', () async {
      final harness = build();
      final controller = await atChoices(
        harness,
        zip(
          playlists: const [],
          problems: const [
            ExportProblem('playlists', 'The playlists could not be read'),
          ],
        ),
      );
      expect(stateOf(harness).disabled, {
        RestorePart.playlists: RestoreRefusal.notInBackup,
      });

      controller.choose(RestorePart.playlists, RestoreChoice.replace);
      final summary = await controller.restore();

      expect(
        stateOf(harness).choices[RestorePart.playlists],
        RestoreChoice.merge,
      );
      expect(harness.playlistStore.writes, 0);
      expect(harness.playlistStore.playlists, [ownPlaylist]);
      expect(harness.playlistCovers.deleted, isEmpty);
      expect(
        (summary.playlists as PartRefused).reason,
        RestoreRefusal.notInBackup,
      );
      expect(summary.history, isA<HistoryRestored>());
      expect(harness.plays.writes, 1);
    });

    test('GivenThePlaylistsHereCannotBeRead_WhenRestored_ThenThatPartIsRefusedAndTheHistoryStillRestored', () async {
      final harness = build();
      harness.playlistStore.failRead = const FileSystemException('locked');
      final controller = await atChoices(harness, zip());
      expect(stateOf(harness).playlistsHere, isNull);

      final summary = await controller.restore();

      expect(
        (summary.playlists as PartRefused).reason,
        RestoreRefusal.unreadableHere,
      );
      expect(harness.playlistStore.writes, 0);
      expect(harness.playlistCovers.covers.keys, ['m']);
      expect(summary.history, isA<HistoryRestored>());
      expect(harness.plays.history.tracks[songB.file.path]!.plays, 4);
    });

    test('GivenTheHistoryHereCannotBeRead_WhenRestored_ThenThatPartIsRefusedAndThePlaylistsStillRestored', () async {
      final harness = build();
      harness.plays.failRead = const FileSystemException('locked');
      final controller = await atChoices(harness, zip());
      expect(stateOf(harness).songsWithPlaysHere, isNull);

      final summary = await controller.restore();

      expect(
        (summary.history as PartRefused).reason,
        RestoreRefusal.unreadableHere,
      );
      expect(harness.plays.writes, 0);
      expect(summary.playlists, isA<PlaylistsRestored>());
      expect(namesIn(harness), ['Mine', 'Theirs']);
    });

    test('GivenAPlaylistsWriteThatFails_WhenRestored_ThenThatPartIsNotWrittenAndTheOthersAre', () async {
      final harness = build();
      final controller = await atChoices(harness, zip());
      harness.playlistStore.failNextWrite = Exception('disk full');

      final summary = await controller.restore();

      expect(
        (summary.playlists as PartRefused).reason,
        RestoreRefusal.notWritten,
      );
      expect(harness.playlistStore.playlists, [ownPlaylist]);
      expect(harness.plays.writes, 1);
      expect(harness.settings.opensPlayerOnPlay, isFalse);
    });

    test('GivenACoverThatCannotBeWritten_WhenRestored_ThenThePlaylistIsKeptAndTheCoverListed', () async {
      final harness = build(playlists: const []);
      // The first id handed out is the backup playlist's own.
      harness.playlistCovers.unwritable.add('id-1');
      final controller = await atChoices(
        harness,
        zip(playlists: [backupPlaylists.last]),
      );

      final summary = await controller.restore();

      expect(namesIn(harness), ['Theirs']);
      expect(summary.coverFailures, ['Theirs']);
      expect(summary.playlists, isA<PlaylistsRestored>());
    });

    test(
      'GivenARestoreUnderWay_WhenAskedAgain_ThenTheOneUnderWayIsAnswered',
      () async {
        final harness = build();
        final controller = await atChoices(harness, zip());

        final first = controller.restore();
        final second = controller.restore();

        expect(await second, same(await first));
        expect(harness.playlistStore.writes, 1);
        expect(harness.plays.writes, 1);
      },
    );

    test('GivenFoldersChangedInTheFirstStage_WhenCancelledInTheSecond_ThenNothingElseIsWrittenAndTheFoldersStay', () async {
      final harness = build();
      harness.fileOpener.next = zip();
      final controller = restorer(harness);
      await controller.pick();
      controller.chooseFolders(['/new']);
      await controller.continueToChoices();

      controller.cancel();

      expect(stateOf(harness).stage, RestoreStage.idle);
      expectNothingWritten(harness);
      expect(harness.settings.libraryFolders, ['/new']);
    });
  });
}
