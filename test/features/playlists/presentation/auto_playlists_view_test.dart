import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/app.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';
import 'package:orpheus/features/playlists/domain/auto_playlists.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlist_cover.dart';
import 'package:orpheus/features/playlists/presentation/playlists_view.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The auto playlists in the Playlists tab: their section, opening one, what
/// can and cannot be done in it, and the preference that hides them.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);
  final earlier = DateTime.utc(2026, 1, 1);

  final a = entry(id: 'a', title: 'Alpha', artist: 'Band', album: 'First');
  final b = entry(id: 'b', title: 'Bravo', artist: 'Band', album: 'First');
  final c = entry(id: 'c', title: 'Charlie', artist: 'Band', album: 'Second');

  final roadTrip = Playlist(
    id: 'p1',
    name: 'Road trip',
    entries: [PlaylistEntry(id: 'e1', path: c.file.path)],
    createdAt: earlier,
    modifiedAt: earlier,
  );

  TrackPlays played(MusicEntry song, int plays, {List<DateTime>? recent}) =>
      TrackPlays(
        path: song.file.path,
        plays: plays,
        lastPlayedAt: now,
        recent: recent ?? [now],
      );

  PlayHistory historyOf(List<TrackPlays> tracks) =>
      PlayHistory(tracks: {for (final track in tracks) track.path: track});

  // Alpha played most, then Bravo; Charlie never. Two songs with recent
  // plays is fewer than *Favourites lately* needs, so it falls back.
  final history = historyOf([played(a, 5), played(b, 2)]);

  Harness harnessOf({
    List<MusicEntry> library = const [],
    PlayHistory? plays,
    List<Playlist> playlists = const [],
    bool showsAutoPlaylists = true,
  }) {
    final harness = Harness(
      library: library.isEmpty ? [a, b, c] : library,
      playlists: playlists,
      now: now,
      settings: InMemorySettingsStore(showsAutoPlaylists: showsAutoPlaylists),
    );
    harness.plays.history = plays ?? history;
    for (final song in library.isEmpty ? [a, b, c] : library) {
      harness.tagWriter.files[song.file.path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: const {AutofillField.artist: 'Band'},
      );
    }

    return harness;
  }

  Future<Harness> show(WidgetTester tester, {Harness? harness}) async {
    final over = harness ?? harnessOf(playlists: [roadTrip]);
    await tester.pumpHarness(over, const Scaffold(body: PlaylistsView()));

    return over;
  }

  Future<Harness> showOpen(
    WidgetTester tester,
    String id, {
    Harness? harness,
  }) async {
    final over = harness ?? harnessOf(playlists: [roadTrip]);
    over.read(playlistBrowseProvider.notifier).open(id);

    return show(tester, harness: over);
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  Finder menuItem(String text) => find.widgetWithText(MenuItemButton, text);

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> hold(WidgetTester tester, Finder target) async {
    await tester.longPress(target);
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder target) =>
      tester.getTopLeft(target).dy;

  List<String> queued(Harness harness) => [
    for (final track
        in harness.read(audioPlaybackControllerProvider).queue.tracks)
      track.path,
  ];

  List<String> titlesInOrder(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  group('the section', () {
    testWidgets(
      'GivenThePreferenceIsOn_WhenTheTabIsShown_ThenTheAutoPlaylistsComeFirstThenYourPlaylists',
      (tester) async {
        await show(tester);

        expect(find.text('Auto playlists'), findsOneWidget);
        expect(find.text('Your playlists'), findsOneWidget);
        expect(row('Favourites lately'), findsOneWidget);
        expect(row('All-time favourites'), findsOneWidget);
        expect(
          top(tester, find.text('Auto playlists')),
          lessThan(top(tester, row('Favourites lately'))),
        );
        expect(
          top(tester, row('All-time favourites')),
          lessThan(top(tester, find.text('Your playlists'))),
        );
        expect(
          top(tester, find.text('Your playlists')),
          lessThan(top(tester, row('Road trip'))),
        );
      },
    );

    testWidgets(
      'GivenPlayedSongs_WhenTheTabIsShown_ThenEachAutoRowHasItsCountAndTheMosaic',
      (tester) async {
        await show(tester);

        final allTime = row('All-time favourites');
        expect(
          find.descendant(of: allTime, matching: find.text('2 songs')),
          findsOneWidget,
        );
        final cover = tester.widget<PlaylistCover>(
          find.descendant(of: allTime, matching: find.byType(PlaylistCover)),
        );
        expect(cover.playlist.coverId, isNull);
      },
    );

    testWidgets(
      'GivenTheTilesLayout_WhenTheTabIsShown_ThenTheAutoPlaylistsAreTilesToo',
      (tester) async {
        final harness = harnessOf(playlists: [roadTrip]);
        await harness
            .read(musicLayoutControllerProvider.notifier)
            .choose(MusicLayout.grid);

        await show(tester, harness: harness);

        expect(find.widgetWithText(Card, 'Favourites lately'), findsOneWidget);
        expect(
          find.widgetWithText(Card, 'All-time favourites'),
          findsOneWidget,
        );
        expect(find.widgetWithText(Card, 'Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenThePreferenceIsOff_WhenTheTabIsShown_ThenThereIsNoAutoSection',
      (tester) async {
        await show(
          tester,
          harness: harnessOf(playlists: [roadTrip], showsAutoPlaylists: false),
        );

        expect(find.text('Auto playlists'), findsNothing);
        expect(find.text('Your playlists'), findsNothing);
        expect(find.text('Favourites lately'), findsNothing);
        expect(row('Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAPlaylistsFileThatCannotBeRead_WhenTheTabIsShown_ThenTheSectionIsAboveTheFailure',
      (tester) async {
        final harness = harnessOf();
        harness.playlistStore.failRead = Exception('unreadable');

        await show(tester, harness: harness);

        expect(row('Favourites lately'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          top(tester, row('All-time favourites')),
          lessThan(top(tester, find.text('Try again'))),
        );
        expect(find.text('New playlist'), findsNothing);
      },
    );

    testWidgets(
      'GivenNoPlaylistsOfTheOwners_WhenTheTabIsShown_ThenYourPlaylistsSaysSoInlineBelowTheSection',
      (tester) async {
        await show(tester, harness: harnessOf());

        expect(row('Favourites lately'), findsOneWidget);
        expect(find.text('No playlists yet'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'New playlist'),
          findsOneWidget,
        );
        expect(
          top(tester, find.text('Your playlists')),
          lessThan(top(tester, find.text('No playlists yet'))),
        );
      },
    );

    testWidgets(
      'GivenTheLibraryIsLoading_WhenTheTabIsShown_ThenTheSectionShowsALoadingRow',
      (tester) async {
        final harness = harnessOf(playlists: [roadTrip]);
        final gate = harness.catalogs.readGate = Completer<void>();
        // Not through `pumpHarness`, which settles: a list still loading
        // never does.
        tester.view.physicalSize = desktopWindow;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: PlaylistsView()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Auto playlists'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(row('Favourites lately'), findsNothing);
        expect(row('Road trip'), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(row('Favourites lately'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenALibraryThatCannotBeRead_WhenTheTabIsShown_ThenThereIsNoAutoSection',
      (tester) async {
        final harness = harnessOf(playlists: [roadTrip]);
        harness.catalogs.failOnRead = true;

        await show(tester, harness: harness);

        expect(find.text('Auto playlists'), findsNothing);
        expect(row('Road trip'), findsOneWidget);
      },
    );

    testWidgets('GivenTheTab_WhenThePreferenceIsTurnedOff_ThenTheSectionGoes', (
      tester,
    ) async {
      final harness = await show(tester);

      await harness
          .read(preferencesControllerProvider.notifier)
          .setShowsAutoPlaylists(false);
      await tester.pumpAndSettle();

      expect(find.text('Auto playlists'), findsNothing);
      expect(row('Road trip'), findsOneWidget);
    });
    testWidgets(
      'GivenA360WidePhoneInPortuguese_WhenTheTabIsShownWithNoPlaylists_ThenEverythingFits',
      (tester) async {
        await tester.pumpHarness(
          harnessOf(),
          const Scaffold(body: PlaylistsView()),
          window: const Size(360, 800),
          locale: const Locale('pt'),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Playlists automáticas'), findsOneWidget);
        expect(row('Favoritas de todos os tempos'), findsOneWidget);
        expect(find.text('Nenhuma playlist ainda'), findsOneWidget);
      },
    );
  });

  group('the menu', () {
    testWidgets(
      'GivenAnAutoRow_WhenItsMenuOpens_ThenItOffersAddAndExportOnly',
      (tester) async {
        await show(tester);

        await tester.tap(row('All-time favourites'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(menuItem('Add to playlist…'), findsOneWidget);
        expect(menuItem('Export to .m3u…'), findsOneWidget);
        expect(menuItem('Rename…'), findsNothing);
        expect(menuItem('Choose cover…'), findsNothing);
        expect(menuItem('Delete…'), findsNothing);
      },
    );

    testWidgets(
      'GivenAnAutoRow_WhenAddToPlaylistIsChosen_ThenAllItsSongsGoToTheChosenPlaylist',
      (tester) async {
        final harness = await show(tester);

        await tester.tap(row('All-time favourites'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tap(tester, menuItem('Add to playlist…'));
        await tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Road trip'),
          ),
        );

        expect(
          [
            for (final entry in harness.playlistStore.playlists.single.entries)
              entry.path,
          ],
          [c.file.path, a.file.path, b.file.path],
        );
        expect(find.text('Added 2 songs to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnAutoRow_WhenItIsExported_ThenTheFileIsNamedAfterThePlaylist',
      (tester) async {
        final harness = await show(tester);

        await tester.tap(row('All-time favourites'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tap(tester, menuItem('Export to .m3u…'));

        final saved = harness.fileSaver.saved.single;
        expect(saved.suggestedName, 'All-time favourites.m3u');
        final text = utf8.decode(saved.bytes);
        expect(text, startsWith('#EXTM3U'));
        expect(text.indexOf(a.file.path), lessThan(text.indexOf(b.file.path)));
        expect(harness.playlistStore.writes, 0);
      },
    );
  });

  group('inside', () {
    testWidgets(
      'GivenAnAutoRow_WhenItIsTapped_ThenItOpensWithItsNameAndSongs',
      (tester) async {
        final harness = await show(tester);

        await tap(tester, row('All-time favourites'));

        expect(harness.read(playlistBrowseProvider), autoAllTimeId);
        expect(find.text('All-time favourites'), findsOneWidget);
        expect(titlesInOrder(tester), ['Alpha', 'Bravo']);
        expect(find.byTooltip('All playlists'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenPlayIsPressed_ThenItsSongsPlayUnderItsName',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);

        await tap(tester, find.widgetWithText(FilledButton, 'Play'));

        expect(queued(harness), [a.file.path, b.file.path]);
        expect(
          harness.read(audioPlaybackControllerProvider).queue.label,
          'All-time favourites',
        );
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenShuffleIsPressed_ThenItsSongsAreQueued',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);

        await tap(tester, find.text('Shuffle'));

        expect(queued(harness).toSet(), {a.file.path, b.file.path});
        expect(
          harness.read(audioPlaybackControllerProvider).queue.label,
          'All-time favourites',
        );
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenItIsShown_ThenThereAreNoDragHandles',
      (tester) async {
        await showOpen(tester, autoAllTimeId);

        expect(find.byIcon(Icons.drag_handle), findsNothing);
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenARowsMenuOpens_ThenThereIsNoRemoveFromPlaylist',
      (tester) async {
        await showOpen(tester, autoAllTimeId);

        await tester.tap(row('Bravo'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(menuItem('Play'), findsOneWidget);
        expect(menuItem('Remove from playlist'), findsNothing);
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenItsOwnMenuOpens_ThenThereIsNoRenameCoverOrDelete',
      (tester) async {
        await showOpen(tester, autoAllTimeId);

        await tap(tester, find.byTooltip('Playlist actions'));

        expect(menuItem('Add to playlist…'), findsOneWidget);
        expect(menuItem('Export to .m3u…'), findsOneWidget);
        expect(menuItem('Rename…'), findsNothing);
        expect(menuItem('Choose cover…'), findsNothing);
        expect(menuItem('Delete…'), findsNothing);
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenARowIsHeld_ThenItIsSelectedByPathWithNoRemove',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);

        await hold(tester, row('Bravo'));

        final selection = harness.read(songSelectionProvider);
        expect(selection.paths, {b.file.path});
        expect(selection.scope, ('playlist', autoAllTimeId));
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byTooltip('Add to playlist…'), findsOneWidget);
        expect(find.byTooltip('Remove from playlist'), findsNothing);
      },
    );

    testWidgets(
      'GivenASelectionInAnAutoPlaylist_WhenAddToPlaylistIsPressed_ThenThoseSongsAreAdded',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);
        await hold(tester, row('Bravo'));

        await tap(tester, find.byTooltip('Add to playlist…'));
        await tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Road trip'),
          ),
        );

        expect(
          [
            for (final entry in harness.playlistStore.playlists.single.entries)
              entry.path,
          ],
          [c.file.path, b.file.path],
        );
      },
    );

    testWidgets(
      'GivenASelectionInAnAutoPlaylist_WhenEditTagsIsPressed_ThenTheFormOpensOverThoseSongs',
      (tester) async {
        await showOpen(tester, autoAllTimeId);
        await hold(tester, row('Alpha'));
        await tap(tester, find.byTooltip('Select all'));

        await tap(tester, find.widgetWithText(FilledButton, 'Edit tags…'));

        final dialog = tester.widget<EditManyTagsDialog>(
          find.byType(EditManyTagsDialog),
        );
        expect(
          [for (final song in dialog.entries) song.file.path],
          [a.file.path, b.file.path],
        );
      },
    );

    testWidgets(
      'GivenTooFewRecentPlays_WhenFavouritesLatelyIsOpen_ThenTheFallbackNoteShows',
      (tester) async {
        await showOpen(tester, autoLatelyId);

        expect(find.text('Favourites lately'), findsOneWidget);
        expect(
          find.text('Getting to know your recent listening'),
          findsOneWidget,
        );
        expect(titlesInOrder(tester), ['Alpha', 'Bravo']);
      },
    );

    testWidgets(
      'GivenEnoughRecentPlays_WhenFavouritesLatelyIsOpen_ThenThereIsNoNote',
      (tester) async {
        final many = [
          for (var i = 0; i < latelyEnough; i++)
            entry(id: 'm$i', title: 'Song $i', artist: 'Band'),
        ];
        await showOpen(
          tester,
          autoLatelyId,
          harness: harnessOf(
            library: many,
            plays: historyOf([for (final song in many) played(song, 1)]),
          ),
        );

        expect(find.text('Song 0'), findsOneWidget);
        expect(
          find.text('Getting to know your recent listening'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GivenAnAllTimeFavouritesFallback_WhenItIsOpen_ThenThereIsNoNote',
      (tester) async {
        await showOpen(tester, autoAllTimeId);

        expect(
          find.text('Getting to know your recent listening'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GivenNothingPlayed_WhenFavouritesLatelyIsOpen_ThenItsEmptyStateShowsWithoutTheNote',
      (tester) async {
        await showOpen(
          tester,
          autoLatelyId,
          harness: harnessOf(plays: PlayHistory.empty),
        );

        expect(
          find.text(
            'Play some music and your recent favourites will show here',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Getting to know your recent listening'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GivenNothingPlayed_WhenAllTimeFavouritesIsOpen_ThenItsEmptyStateShows',
      (tester) async {
        await showOpen(
          tester,
          autoAllTimeId,
          harness: harnessOf(plays: PlayHistory.empty),
        );

        expect(
          find.text('Play some music and your favourites will show here'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenThePreferenceIsTurnedOff_ThenItClosesToTheList',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);

        await harness
            .read(preferencesControllerProvider.notifier)
            .setShowsAutoPlaylists(false);
        await tester.pumpAndSettle();

        expect(harness.read(openPlaylistProvider), isNull);
        expect(find.byTooltip('All playlists'), findsNothing);
        expect(row('Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnOpenAutoPlaylist_WhenAllPlaylistsIsPressed_ThenTheListIsBack',
      (tester) async {
        final harness = await showOpen(tester, autoAllTimeId);

        await tap(tester, find.byTooltip('All playlists'));

        expect(harness.read(playlistBrowseProvider), isNull);
        expect(row('Favourites lately'), findsOneWidget);
      },
    );

    testWidgets('GivenAnOpenAutoPlaylist_WhenBackIsPressed_ThenTheListIsBack', (
      tester,
    ) async {
      final harness = harnessOf(playlists: [roadTrip]);
      tester.view.physicalSize = desktopWindow;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const OrpheusApp(),
        ),
      );
      await tester.pumpAndSettle();
      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.playlists);
      harness.read(playlistBrowseProvider.notifier).open(autoAllTimeId);
      await tester.pumpAndSettle();
      expect(find.byTooltip('All playlists'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(playlistBrowseProvider), isNull);
      expect(row('Favourites lately'), findsOneWidget);
    });
  });
}
