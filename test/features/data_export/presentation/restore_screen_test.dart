import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/failures/failure.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/data_export/application/restore_controller.dart';
import 'package:orpheus/features/data_export/data/zip_backup_codec.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/data_export/domain/restore_plan.dart';
import 'package:orpheus/features/data_export/presentation/restore_screen.dart';
import 'package:orpheus/features/data_export/presentation/restore_tile.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/shell/presentation/preferences_dialog.dart';
import 'package:orpheus/features/stats/application/play_recorder.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The restore screen: the two stages, what each shows and does, the progress
/// between them, and the summary.
void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  final made = DateTime.utc(2026, 10, 1, 12);

  final songA = entry(id: 'a', title: 'Alpha', artist: 'Ann', album: 'One');
  final songB = entry(id: 'b', title: 'Beta', artist: 'Ann', album: 'One');
  final library = [songA, songB];

  PlaylistEntry entryOf(String id, MusicEntry song) =>
      PlaylistEntry(id: id, path: song.file.path, title: song.title);

  Playlist playlist(String id, String name, List<MusicEntry> songs) => Playlist(
    id: id,
    name: name,
    entries: [
      for (final (index, song) in songs.indexed) entryOf('$id-$index', song),
    ],
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

  PreferencesSnapshot preferencesWith(List<String> folders) =>
      PreferencesSnapshot(
        themeMode: 'light',
        locale: 'pt_BR',
        opensPlayerOnPlay: false,
        rescansAtStartup: true,
        fetchesLyricsOnline: true,
        checksForUpdatesOnStartup: true,
        showsAutoPlaylists: true,
        volume: 0.5,
        libraryFolders: folders,
      );

  // A playlist sharing a name with the owner's, one that is new, and plays of
  // both songs.
  final backupPlaylists = [
    playlist('b1', 'Mine', [songA, songB]),
    playlist('b2', 'Theirs', [songB]),
  ];
  final backupHistory = historyOf([plays(songA, 2), plays(songB, 4)]);

  Map<String, Object?> dataOf({List<ExportProblem> problems = const []}) =>
      buildDataExport(
        ExportSources(
          songs: library,
          playlists: backupPlaylists,
          history: backupHistory,
          now: made,
          problems: problems,
        ),
      );

  Uint8List zip({
    List<String> folders = const ['/old/Music', '/music'],
    List<ExportProblem> problems = const [],
  }) => encodeBackupZip(
    data: dataOf(problems: problems),
    preferences: preferencesWith(folders),
    covers: {
      'b2': Uint8List.fromList([0xFF, 0xD8, 0xFF, 2]),
    },
    createdAt: made,
  );

  // A backup that holds no playlist and no play.
  Uint8List emptyZip() => encodeBackupZip(
    data: buildDataExport(
      ExportSources(
        songs: library,
        playlists: const [],
        history: PlayHistory.empty,
        now: made,
      ),
    ),
    preferences: preferencesWith(const ['/music']),
    covers: const {},
    createdAt: made,
  );

  Uint8List json() => encodeDataExport(dataOf());

  // The owner's own data: a playlist called as one of the backup's, plays of
  // one song, and a theme they chose.
  final ownPlaylist = playlist('m', 'Mine', [songA]);
  final ownHistory = historyOf([plays(songA, 5)]);

  Harness build({
    List<String> folders = const ['/music'],
    Set<String> existing = const {'/music'},
    LibraryScanner? scanner,
    FakeFolderPicker? picker,
    bool emptyLibrary = false,
    InMemorySettingsStore? settings,
    List<Override> overrides = const [],
  }) {
    final harness = Harness(
      library: emptyLibrary ? const [] : library,
      playlists: [ownPlaylist],
      now: now,
      existingFolders: {...existing},
      picker: picker,
      settings:
          settings ??
          InMemorySettingsStore(
            themeMode: ThemeMode.dark,
            libraryFolders: folders,
          ),
      scanner:
          scanner ??
          ScriptedScanner([
            ScanCompleted(
              catalog: MusicCatalog(
                entries: albumArtistsAcross(library),
                scannedAt: now,
              ),
              report: const ScanReport(
                tracks: 2,
                added: 1,
                removed: 0,
                reused: 0,
              ),
            ),
          ]),
      overrides: overrides,
    );
    harness.plays.history = ownHistory;

    return harness;
  }

  ScriptedScanner scannerOf(Harness harness) =>
      harness.read(libraryScannerProvider) as ScriptedScanner;

  Future<void> start(
    WidgetTester tester,
    Harness harness,
    Uint8List? file, {
    Size window = desktopWindow,
    Locale locale = const Locale('en'),
  }) async {
    harness.fileOpener.next = file;
    await tester.pumpHarness(
      harness,
      const Scaffold(body: RestoreTile()),
      window: window,
      locale: locale,
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Presses *Continue* (or its Portuguese) and waits until the choices show.
  ///
  /// Applying folders resolves links on the real disk, which fake time never
  /// reaches, so the wait gives the real clock a turn between frames.
  Future<void> toChoices(
    WidgetTester tester, {
    String label = 'Continue',
  }) async {
    await tester.tap(find.text(label));
    for (
      var turn = 0;
      turn < 50 &&
          find.byType(SegmentedButton<RestoreChoice>).evaluate().isEmpty;
      turn++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Finder part(String name) => find.byKey(ValueKey('restore-part-$name'));

  Finder inPart(String name, String text) =>
      find.descendant(of: part(name), matching: find.text(text));

  Set<RestoreChoice> selectedIn(WidgetTester tester, String name) => tester
      .widget<SegmentedButton<RestoreChoice>>(
        find.descendant(
          of: part(name),
          matching: find.byType(SegmentedButton<RestoreChoice>),
        ),
      )
      .selected;

  Future<void> choose(WidgetTester tester, String name, String label) async {
    await tester.tap(inPart(name, label));
    await tester.pumpAndSettle();
  }

  group('the entry', () {
    testWidgets(
      'GivenThePreferences_WhenTheyOpen_ThenTheSectionOffersRestoreAndTappingItAsksForTheFile',
      (tester) async {
        final harness = build();
        harness.fileOpener.next = zip();
        await tester.pumpHarness(
          harness,
          const _OpenPreferences(),
          window: const Size(1400, 1400),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(ListTile, 'Restore from a backup…');
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(PreferencesDialog),
            matching: find.textContaining('Bring back'),
          ),
          findsOneWidget,
        );

        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(harness.fileOpener.requests, [
          ['zip', 'json'],
        ]);
        expect(find.byType(RestoreScreen), findsOneWidget);
        expect(find.text('Your music'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheDialogIsCancelled_WhenRestoreIsTapped_ThenNoScreenOpens',
      (tester) async {
        await start(tester, build(), null);

        expect(find.byType(RestoreScreen), findsNothing);
      },
    );
  });

  group('stage 1, your music', () {
    testWidgets(
      'GivenABackupZip_WhenPicked_ThenItsFoldersAreMarkedAndTheDevicesAreListed',
      (tester) async {
        await start(tester, build(), zip());

        expect(find.text('Your music'), findsOneWidget);
        expect(find.text('/old/Music'), findsOneWidget);
        expect(find.text('/music'), findsNWidgets(2));
        expect(find.text('Not found'), findsOneWidget);
        expect(find.text('Found on this device'), findsOneWidget);
        expect(find.text('Choose folders…'), findsOneWidget);
        expect(
          find.textContaining('Continue changes your music folders now'),
          findsOneWidget,
        );
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('What to restore'), findsNothing);
      },
    );

    testWidgets(
      'GivenAFolderIsChosen_WhenTheStageShows_ThenTheStagedSetIsShownAsTheWholeSet',
      (tester) async {
        final harness = build(picker: FakeFolderPicker('/new'));
        await start(tester, harness, zip());
        expect(find.text('Changes when you continue'), findsNothing);

        await tapText(tester, 'Choose folders…');

        expect(find.text('Changes when you continue'), findsOneWidget);
        // The device's own folder and the one picked, both in the set.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('restore-device-folders')),
            matching: find.text('/new'),
          ),
          findsOneWidget,
        );
        // Staged, not written.
        expect(harness.settings.libraryFolders, ['/music']);
      },
    );

    testWidgets(
      'GivenAStagedFolder_WhenItIsRemoved_ThenTheSetNoLongerHoldsIt',
      (tester) async {
        final harness = build(picker: FakeFolderPicker('/new'));
        await start(tester, harness, zip());
        await tapText(tester, 'Choose folders…');

        await tester.tap(find.byTooltip('Remove /music'));
        await tester.pumpAndSettle();

        final set = find.byKey(const ValueKey('restore-device-folders'));
        expect(
          find.descendant(of: set, matching: find.text('/music')),
          findsNothing,
        );
        expect(
          find.descendant(of: set, matching: find.text('/new')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenTheFolderDialogIsDismissed_WhenChoosing_ThenNothingIsStaged',
      (tester) async {
        await start(tester, build(picker: FakeFolderPicker()), zip());

        await tapText(tester, 'Choose folders…');

        expect(find.text('Changes when you continue'), findsNothing);
      },
    );

    testWidgets(
      'GivenADeviceWithNoFolders_WhenPicked_ThenTheBackupFoldersHereAreAlreadyStaged',
      (tester) async {
        final harness = build(folders: const []);
        await start(tester, harness, zip());

        expect(find.text('None yet'), findsNothing);
        expect(find.text('Changes when you continue'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('restore-device-folders')),
            matching: find.text('/music'),
          ),
          findsOneWidget,
        );

        await toChoices(tester);

        expect(harness.settings.libraryFolders, ['/music']);
        expect(scannerOf(harness).requests, [
          ['/music'],
        ]);
        expect(find.text('What to restore'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenADeviceWithNoFoldersAndNoneOfTheBackupsHere_WhenPicked_ThenTheDeviceListSaysNone',
      (tester) async {
        await start(
          tester,
          build(folders: const [], existing: const {}),
          zip(),
        );

        expect(find.text('None yet'), findsOneWidget);
        expect(find.text('Changes when you continue'), findsNothing);
      },
    );

    testWidgets(
      'GivenEveryFolderIsRemoved_WhenTheSetIsEmpty_ThenItWarnsThatNoSongsCanBeMatched',
      (tester) async {
        await start(tester, build(), zip());
        expect(find.textContaining('All your music folders'), findsNothing);

        await tester.tap(find.byTooltip('Remove /music'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'All your music folders will be removed, so no songs can be '
            'matched.',
          ),
          findsOneWidget,
        );
        expect(find.text('None yet'), findsNothing);
      },
    );

    testWidgets(
      'GivenTheScanIsRunning_WhenContinuing_ThenProgressIsShownAndTheScreenCannotBeLeft',
      (tester) async {
        final scanner = _GatedScanner(now);
        // An empty library is scanned on the way in, with no folder changed.
        final harness = build(scanner: scanner, emptyLibrary: true);
        await start(tester, harness, zip());

        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump();
        scanner.emit(
          const ScanProgress(filesFound: 10, filesRead: 4, walking: false),
        );
        await tester.pump();

        expect(find.text('Scanning your music…'), findsOneWidget);
        expect(find.text('Reading 4 of 10'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Continue'), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(RestoreScreen), findsOneWidget);

        scanner.finish();
        await tester.pumpAndSettle();

        expect(find.text('What to restore'), findsOneWidget);
      },
    );
  });

  group('stage 2, what to restore', () {
    testWidgets(
      'GivenTheChoicesStage_WhenShown_ThenItSaysWhatTheFileHoldsAndEveryPartIsMerge',
      (tester) async {
        await start(tester, build(), zip());
        await toChoices(tester);

        expect(find.text('What to restore'), findsOneWidget);
        expect(find.textContaining('2026'), findsOneWidget);
        expect(find.text('2 playlists'), findsOneWidget);
        expect(find.text('2 songs with plays'), findsOneWidget);
        expect(find.text('1 playlist cover'), findsOneWidget);
        expect(find.text('Preferences included'), findsOneWidget);
        for (final name in ['playlists', 'history', 'preferences']) {
          expect(part(name), findsOneWidget);
          expect(selectedIn(tester, name), {RestoreChoice.merge});
          expect(inPart(name, 'Merge'), findsOneWidget);
          expect(inPart(name, 'Skip'), findsOneWidget);
          expect(inPart(name, 'Replace'), findsOneWidget);
        }
        expect(inPart('playlists', 'Playlists'), findsOneWidget);
        expect(inPart('history', 'Play history'), findsOneWidget);
        expect(inPart('preferences', 'Preferences'), findsOneWidget);
        expect(find.text('Restore'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenEachChoice_WhenSelected_ThenItsOneLineDescriptionForThatPartIsShown',
      (tester) async {
        await start(tester, build(), zip());
        await toChoices(tester);
        expect(
          inPart(
            'playlists',
            "Adds the backup's playlists that aren't here, and the songs your same-named ones lack.",
          ),
          findsOneWidget,
        );
        expect(
          inPart(
            'history',
            'Keeps the higher play count and the later date for each song, and adds the rest.',
          ),
          findsOneWidget,
        );
        expect(
          inPart(
            'preferences',
            "Applies the backup's settings only where yours are still the default.",
          ),
          findsOneWidget,
        );

        await choose(tester, 'playlists', 'Skip');
        await choose(tester, 'history', 'Skip');
        await choose(tester, 'preferences', 'Skip');

        expect(
          inPart(
            'playlists',
            "Adds only the backup's playlists whose name isn't here.",
          ),
          findsOneWidget,
        );
        expect(
          inPart('history', 'Adds only songs with no play history here.'),
          findsOneWidget,
        );
        expect(
          inPart('preferences', 'Changes none of your settings.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('GivenReplace_WhenSelected_ThenTheWarningSaysWhatItRemoves', (
      tester,
    ) async {
      await start(tester, build(), zip());
      await toChoices(tester);
      expect(find.textContaining('Replaces your'), findsNothing);

      await choose(tester, 'playlists', 'Replace');
      await choose(tester, 'history', 'Replace');
      await choose(tester, 'preferences', 'Replace');

      expect(selectedIn(tester, 'playlists'), {RestoreChoice.replace});
      expect(inPart('playlists', 'Replaces your 1 playlist'), findsOneWidget);
      expect(
        inPart('history', 'Replaces play counts for 1 song'),
        findsOneWidget,
      );
      expect(
        inPart('preferences', "Replaces all your settings with the backup's"),
        findsOneWidget,
      );
    });

    testWidgets(
      'GivenADataJson_WhenPicked_ThenItGoesStraightToTheChoicesWithPreferencesDisabled',
      (tester) async {
        await start(tester, build(), json());

        expect(find.text('Your music'), findsNothing);
        expect(find.text('What to restore'), findsOneWidget);
        expect(find.text('Preferences included'), findsNothing);
        expect(inPart('preferences', 'Not in this file'), findsOneWidget);
        final buttons = tester.widget<SegmentedButton<RestoreChoice>>(
          find.descendant(
            of: part('preferences'),
            matching: find.byType(SegmentedButton<RestoreChoice>),
          ),
        );
        expect(buttons.onSelectionChanged, isNull);

        await tester.tap(inPart('preferences', 'Replace'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(selectedIn(tester, 'preferences'), {RestoreChoice.merge});
      },
    );

    testWidgets(
      'GivenABackupThatCouldNotReadItsPlaylists_WhenShown_ThenThatPartIsDisabledAsNotInThisBackup',
      (tester) async {
        await start(
          tester,
          build(),
          zip(problems: const [ExportProblem('playlists', 'unreadable')]),
        );
        await toChoices(tester);

        expect(inPart('playlists', 'Not in this backup'), findsOneWidget);
        expect(inPart('history', 'Not in this backup'), findsNothing);
        expect(
          tester
              .widget<SegmentedButton<RestoreChoice>>(
                find.descendant(
                  of: part('playlists'),
                  matching: find.byType(SegmentedButton<RestoreChoice>),
                ),
              )
              .onSelectionChanged,
          isNull,
        );
      },
    );

    testWidgets(
      'GivenTheFoldersWereChanged_WhenTheChoicesShow_ThenCancelSaysTheyStay',
      (tester) async {
        final harness = build(picker: FakeFolderPicker('/new'));
        await start(tester, harness, zip());
        await tapText(tester, 'Choose folders…');
        await toChoices(tester);

        expect(
          find.textContaining('Cancelling keeps your music folders'),
          findsOneWidget,
        );

        await tapText(tester, 'Cancel');

        expect(find.byType(RestoreScreen), findsNothing);
        expect(harness.settings.libraryFolders, ['/music', '/new']);
        expect(
          harness.read(restoreControllerProvider).stage,
          RestoreStage.idle,
        );
      },
    );

    testWidgets(
      'GivenAScanThatFailed_WhenTheChoicesShow_ThenTheySaySongsMayNotBeFound',
      (tester) async {
        final harness = build(
          picker: FakeFolderPicker('/new'),
          scanner: ScriptedScanner(const [ScanFailed(UnexpectedFailure())]),
        );
        await start(tester, harness, zip());
        await tapText(tester, 'Choose folders…');
        await toChoices(tester);

        expect(
          find.text(
            "Your music couldn't be scanned, so some songs in the backup may "
            'not be found in your library.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenAScanThatWorked_WhenTheChoicesShow_ThenNoWordIsSaidAboutIt',
      (tester) async {
        final harness = build(picker: FakeFolderPicker('/new'));
        await start(tester, harness, zip());
        await tapText(tester, 'Choose folders…');
        await toChoices(tester);

        expect(find.textContaining("couldn't be scanned"), findsNothing);
      },
    );

    testWidgets(
      'GivenTheFoldersWereNotChanged_WhenTheChoicesShow_ThenNoWordIsSaidAboutKeepingThem',
      (tester) async {
        await start(tester, build(), zip());
        await toChoices(tester);

        expect(find.textContaining('Cancelling keeps'), findsNothing);
      },
    );
  });

  group('restoring', () {
    testWidgets(
      'GivenTheDefaults_WhenRestoreIsPressed_ThenTheSummaryListsWhatWasRestored',
      (tester) async {
        final harness = build();
        await start(tester, harness, zip());
        await toChoices(tester);

        await tapText(tester, 'Restore');

        expect(find.text('Restore finished'), findsOneWidget);
        expect(find.text('Restored'), findsOneWidget);
        expect(find.text('Playlists: 1 added, 1 merged'), findsOneWidget);
        expect(find.text('Play history for 2 songs'), findsOneWidget);
        expect(find.text('Preferences applied'), findsOneWidget);
        expect(find.text("Couldn't restore"), findsNothing);
        expect(find.text('Close'), findsOneWidget);
        expect(harness.plays.history.tracks[songB.file.path]?.plays, 4);
      },
    );

    testWidgets(
      'GivenSongsTheLibraryDoesNotHold_WhenRestored_ThenTheSummaryCountsThem',
      (tester) async {
        final harness = build();
        final stranger = entry(
          id: 'z',
          title: 'Zed',
          artist: 'Zoe',
          album: 'Q',
        );
        final file = encodeBackupZip(
          data: buildDataExport(
            ExportSources(
              songs: [stranger],
              playlists: const [],
              history: historyOf([plays(stranger, 3)]),
              now: made,
            ),
          ),
          preferences: preferencesWith(const ['/music']),
          covers: const {},
          createdAt: made,
        );
        await start(tester, harness, file);
        await toChoices(tester);

        await tapText(tester, 'Restore');

        expect(
          find.text('Play history for 1 song (1 not in your library)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenPlaylistsThatCannotBeReadHere_WhenRestored_ThenTheRefusedPartIsShownWithItsReason',
      (tester) async {
        final harness = build();
        harness.playlistStore.failRead = const FileSystemException('no access');
        await start(tester, harness, zip());
        await toChoices(tester);

        await tapText(tester, 'Restore');

        expect(find.text("Couldn't restore"), findsOneWidget);
        expect(
          find.text(
            "Playlists: this part couldn't be read here, so it was left alone",
          ),
          findsOneWidget,
        );
        // The others went ahead.
        expect(find.text('Play history for 2 songs'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAPartTheBackupCouldNotRead_WhenRestored_ThenTheSummaryNamesItAsNotRestored',
      (tester) async {
        await start(
          tester,
          build(),
          zip(problems: const [ExportProblem('playHistory', 'unreadable')]),
        );
        await toChoices(tester);

        await tapText(tester, 'Restore');

        expect(
          find.text(
            "Play history: the backup couldn't read this part when it was made",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenAJsonWithNoPreferences_WhenRestored_ThenThePreferencesAreNamedAsNotInThisFile',
      (tester) async {
        await start(tester, build(), json());

        await tapText(tester, 'Restore');

        expect(
          find.text("Preferences: this file doesn't have this part"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenAPlaylistWhoseCoverCouldNotBeSaved_WhenRestored_ThenTheSummaryNamesIt',
      (tester) async {
        final harness = build();
        // Whichever id the new playlist is given.
        harness.playlistCovers.unwritable.addAll([
          for (var i = 1; i < 10; i++) 'id-$i',
        ]);
        await start(tester, harness, zip());
        await toChoices(tester);

        await tapText(tester, 'Restore');

        expect(
          find.text(
            "These playlists are back, but their cover pictures couldn't be saved: Theirs",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenReplaceWithABackupThatHoldsNothing_WhenRestored_ThenTheSummarySaysWhatWasEmptied',
      (tester) async {
        final harness = build();
        await start(tester, harness, emptyZip());
        await toChoices(tester);
        await choose(tester, 'playlists', 'Replace');
        await choose(tester, 'history', 'Replace');

        await tapText(tester, 'Restore');

        expect(harness.plays.history.tracks, isEmpty);
        expect(harness.playlistStore.playlists, isEmpty);
        expect(
          find.text('Playlists: removed your 1 playlist; the backup had none'),
          findsOneWidget,
        );
        expect(
          find.text('Play history replaced; the backup had no plays'),
          findsOneWidget,
        );
        expect(find.textContaining('nothing to add'), findsNothing);
        expect(find.textContaining('no songs to add'), findsNothing);
      },
    );

    testWidgets(
      'GivenSkipForEveryPart_WhenRestoredWithNothingNew_ThenEachLineSaysItWasSkipped',
      (tester) async {
        await start(tester, build(), emptyZip());
        await toChoices(tester);
        await choose(tester, 'playlists', 'Skip');
        await choose(tester, 'history', 'Skip');
        await choose(tester, 'preferences', 'Skip');

        await tapText(tester, 'Restore');

        expect(find.text('Playlists: you chose to skip it'), findsOneWidget);
        expect(find.text('Play history: you chose to skip it'), findsOneWidget);
        expect(find.text('Preferences: you chose to skip it'), findsOneWidget);
        expect(find.textContaining('nothing'), findsNothing);
      },
    );

    testWidgets(
      'GivenACoverThatCouldNotBeSaved_WhenRestored_ThenItsLineHasTheWarningIconAndTheOthersTheCheck',
      (tester) async {
        final harness = build();
        harness.playlistCovers.unwritable.addAll([
          for (var i = 1; i < 10; i++) 'id-$i',
        ]);
        await start(tester, harness, zip());
        await toChoices(tester);

        await tapText(tester, 'Restore');

        Finder iconBeside(String text, IconData icon) => find.descendant(
          of: find.ancestor(
            of: find.textContaining(text),
            matching: find.byType(Row),
          ),
          matching: find.byIcon(icon),
        );
        expect(
          iconBeside('their cover pictures', Icons.warning_amber_outlined),
          findsOneWidget,
        );
        expect(
          iconBeside('Playlists: 1 added', Icons.check_circle_outline),
          findsOneWidget,
        );
        expect(
          iconBeside('their cover pictures', Icons.check_circle_outline),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GivenPreferencesThatCouldNotBeSaved_WhenRestored_ThenTheirLineHasTheWarningIcon',
      (tester) async {
        final harness = build(
          settings: UnwritableSettingsStore(libraryFolders: const ['/music']),
        );
        await start(tester, harness, zip());
        await toChoices(tester);

        await tapText(tester, 'Restore');

        final line = find.text(
          "Some preferences couldn't be saved and last only until Orpheus "
          'closes',
        );
        expect(line, findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(of: line, matching: find.byType(Row)).first,
            matching: find.byIcon(Icons.warning_amber_outlined),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenARestoreUnderWay_WhenItRuns_ThenProgressIsShownAndTheScreenCannotBeLeft',
      (tester) async {
        final harness = build();
        await start(tester, harness, zip());
        await toChoices(tester);
        final gate = Completer<void>();
        harness.plays.writeGate = gate;

        await tester.tap(find.text('Restore'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Restoring…'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(RestoreScreen), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.text('Restore finished'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheSummary_WhenClosed_ThenTheScreenGoesAndTheRestoreIsOver',
      (tester) async {
        final harness = build();
        await start(tester, harness, zip());
        await toChoices(tester);
        await tapText(tester, 'Restore');

        await tapText(tester, 'Close');

        expect(find.byType(RestoreScreen), findsNothing);
        expect(
          harness.read(restoreControllerProvider).stage,
          RestoreStage.idle,
        );
      },
    );
  });

  group('a file that cannot be restored', () {
    testWidgets('GivenAFileThatIsNotABackup_WhenPicked_ThenTheScreenSaysSo', (
      tester,
    ) async {
      final harness = build();
      await start(tester, harness, Uint8List.fromList(utf8.encode('hello')));

      expect(find.byType(RestoreScreen), findsOneWidget);
      expect(find.text("This isn't an Orpheus backup"), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Restore'), findsNothing);

      await tapText(tester, 'Close');

      expect(find.byType(RestoreScreen), findsNothing);
      expect(harness.plays.writes, 0);
    });

    testWidgets(
      'GivenABackupFromANewerOrpheus_WhenPicked_ThenTheScreenSaysToUpdateFirst',
      (tester) async {
        await start(
          tester,
          build(),
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({'format': 'orpheus-data', 'formatVersion': 9}),
            ),
          ),
        );

        expect(
          find.text('This backup is from a newer Orpheus — update first'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenARestoreThatCannotBePrepared_WhenPicked_ThenTheScreenSaysSoAndCloses',
      (tester) async {
        final harness = build(
          overrides: [
            playRecorderProvider.overrideWithValue(_UnreadyRecorder(now)),
          ],
        );
        await start(tester, harness, json());

        expect(
          find.text(
            'Something went wrong while preparing the restore. Nothing was '
            'restored.',
          ),
          findsOneWidget,
        );
        expect(find.text('Restore'), findsNothing);

        await tapText(tester, 'Close');

        expect(find.byType(RestoreScreen), findsNothing);
        expect(harness.playlistStore.writes, 0);
        // No folder was changed, so there is no note about them.
        expect(find.textContaining('music folders were changed'), findsNothing);
      },
    );

    testWidgets(
      'GivenTheFoldersWereChanged_WhenTheRestoreCannotBePrepared_ThenTheScreenSaysTheyStay',
      (tester) async {
        final harness = build(
          picker: FakeFolderPicker('/new'),
          overrides: [
            playRecorderProvider.overrideWithValue(_UnreadyRecorder(now)),
          ],
        );
        await start(tester, harness, zip());
        await tapText(tester, 'Choose folders…');
        await toChoices(tester);

        expect(
          find.textContaining('Something went wrong while preparing'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Your music folders were changed in the last step, and they '
            'stay as they are now.',
          ),
          findsOneWidget,
        );
        expect(harness.settings.libraryFolders, ['/music', '/new']);
      },
    );
  });

  group('the summary in words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ptBr = lookupAppLocalizations(const Locale('pt', 'BR'));

    test('GivenOneOrMorePlaylistsRemoved_WhenTheBackupHadNone_ThenTheLineCountsThemInEitherLanguage', () {
      expect(
        en.restoreDonePlaylistsEmptied(1),
        'Playlists: removed your 1 playlist; the backup had none',
      );
      expect(
        en.restoreDonePlaylistsEmptied(3),
        'Playlists: removed your 3 playlists; the backup had none',
      );
      expect(
        ptBr.restoreDonePlaylistsEmptied(1),
        'Playlists: a sua playlist foi removida; o backup não tinha nenhuma',
      );
      expect(
        ptBr.restoreDonePlaylistsEmptied(3),
        'Playlists: as suas 3 playlists foram removidas; o backup não tinha '
        'nenhuma',
      );
    });

    test('GivenOneOrMorePlaylistsReplaced_WhenTheBackupHadSome_ThenTheLineCountsThemInEitherLanguage', () {
      expect(
        en.restoreDonePlaylistsReplaced(1, 2),
        'Playlists: replaced your 1 playlist with 2 from the backup',
      );
      expect(
        en.restoreDonePlaylistsReplaced(3, 2),
        'Playlists: replaced your 3 playlists with 2 from the backup',
      );
      expect(
        ptBr.restoreDonePlaylistsReplaced(1, 2),
        'Playlists: a sua playlist foi trocada por 2 do backup',
      );
      expect(
        ptBr.restoreDonePlaylistsReplaced(3, 2),
        'Playlists: as suas 3 playlists foram trocadas por 2 do backup',
      );
    });
  });

  group('at 360dp in Portuguese', () {
    const phone = Size(360, 740);
    const pt = Locale('pt', 'BR');

    testWidgets('GivenTheFoldersStage_WhenShownOnAPhone_ThenNothingOverflows', (
      tester,
    ) async {
      final harness = build(
        picker: FakeFolderPicker('/storage/emulated/0/Music/Some/Deep/Folder'),
      );
      await start(tester, harness, zip(), window: phone, locale: pt);
      await tapText(tester, 'Escolher pastas…');

      expect(find.text('Sua música'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'GivenTheChoicesStage_WhenShownOnAPhoneWithEveryReplace_ThenNothingOverflows',
      (tester) async {
        final harness = build();
        await start(tester, harness, zip(), window: phone, locale: pt);
        await toChoices(tester, label: 'Continuar');
        for (final name in ['playlists', 'history', 'preferences']) {
          await choose(tester, name, 'Substituir');
        }

        expect(find.text('O que restaurar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // The segments are whole: the longest label is not clipped to its
        // button.
        for (final name in ['playlists', 'history', 'preferences']) {
          final label = tester.getSize(inPart(name, 'Substituir'));
          final button = tester.getSize(
            find.descendant(
              of: part(name),
              matching: find.byType(SegmentedButton<RestoreChoice>),
            ),
          );
          expect(label.width, lessThan(button.width / 3));
        }
      },
    );

    testWidgets(
      'GivenPartsThatCannotBeRestored_WhenShownOnAPhone_ThenNothingOverflows',
      (tester) async {
        final harness = build();
        harness.playlistStore.failRead = const FileSystemException('no access');
        await start(
          tester,
          harness,
          zip(problems: const [ExportProblem('playHistory', 'unreadable')]),
          window: phone,
          locale: pt,
        );
        await toChoices(tester, label: 'Continuar');
        await choose(tester, 'preferences', 'Substituir');

        expect(
          find.textContaining('Não foi possível ler as suas playlists'),
          findsOneWidget,
        );
        expect(inPart('history', 'Não está neste backup'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tapText(tester, 'Restaurar');

        expect(find.text('Não foi possível restaurar'), findsOneWidget);
        expect(
          find.textContaining('Playlists: esta parte não pôde ser lida aqui'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenTheNewWarningsAndLines_WhenShownOnAPhone_ThenNothingOverflows',
      (tester) async {
        final harness = build();
        await start(tester, harness, emptyZip(), window: phone, locale: pt);
        await tester.tap(find.byTooltip('Remover /music'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Todas as suas pastas'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await toChoices(tester, label: 'Continuar');
        await choose(tester, 'playlists', 'Substituir');
        await choose(tester, 'history', 'Substituir');
        await choose(tester, 'preferences', 'Ignorar');
        await tapText(tester, 'Restaurar');

        expect(
          find.text(
            'Playlists: a sua playlist foi removida; o backup não tinha '
            'nenhuma',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Preferências: você escolheu ignorar'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenAFailedRestoreAfterTheFoldersChanged_WhenShownOnAPhone_ThenNothingOverflows',
      (tester) async {
        final harness = build(
          picker: FakeFolderPicker('/new'),
          overrides: [
            playRecorderProvider.overrideWithValue(_UnreadyRecorder(now)),
          ],
        );
        await start(tester, harness, zip(), window: phone, locale: pt);
        await tapText(tester, 'Escolher pastas…');
        await toChoices(tester, label: 'Continuar');

        expect(
          find.textContaining('Suas pastas de música foram mudadas'),
          findsOneWidget,
        );
        expect(find.text('Fechar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenAScanThatFailed_WhenTheChoicesShowOnAPhone_ThenNothingOverflows',
      (tester) async {
        final harness = build(
          picker: FakeFolderPicker('/new'),
          scanner: ScriptedScanner(const [ScanFailed(UnexpectedFailure())]),
        );
        await start(tester, harness, zip(), window: phone, locale: pt);
        await tapText(tester, 'Escolher pastas…');
        await toChoices(tester, label: 'Continuar');

        expect(
          find.textContaining('Não foi possível examinar sua música'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('GivenTheSummary_WhenShownOnAPhone_ThenNothingOverflows', (
      tester,
    ) async {
      final harness = build();
      await start(tester, harness, zip(), window: phone, locale: pt);
      await toChoices(tester, label: 'Continuar');
      await tapText(tester, 'Restaurar');

      expect(find.text('Restauração concluída'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A scanner that reports progress when the test says, and finishes when it
/// says.
class _GatedScanner implements LibraryScanner {
  _GatedScanner(this.now);

  final DateTime now;
  final StreamController<ScanEvent> _events = StreamController();

  void emit(ScanProgress progress) => _events.add(ScanAdvanced(progress));

  void finish() {
    _events.add(
      ScanCompleted(
        catalog: MusicCatalog(entries: const [], scannedAt: now),
        report: const ScanReport(tracks: 0, added: 0, removed: 0, reused: 0),
      ),
    );
    unawaited(_events.close());
  }

  @override
  Stream<ScanEvent> scan({
    required List<String> folders,
    required MusicCatalog previous,
    required String coverDirectory,
  }) => _events.stream;
}

/// A button that opens the preferences, so the section has a navigator.
class _OpenPreferences extends StatelessWidget {
  const _OpenPreferences();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => PreferencesDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}

/// A recorder that cannot answer what it holds: something a restore does not
/// expect to go wrong.
class _UnreadyRecorder extends PlayRecorder {
  _UnreadyRecorder(DateTime now)
    : super(store: InMemoryPlayHistoryStore(), clock: () => now);

  @override
  Future<PlayHistory> current() =>
      Future.error(StateError('the history is not there'));
}
