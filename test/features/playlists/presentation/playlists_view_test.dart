import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';
import 'package:orpheus/features/playback/presentation/album_art.dart';
import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlist_cover.dart';
import 'package:orpheus/features/playlists/presentation/playlists_view.dart';

import '../../../support/entries.dart';
import '../../../support/fake_playlists.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The Playlists tab: the list of them, making one, and each one's menu.
void main() {
  final now = DateTime.utc(2026, 6, 1, 12);
  final earlier = DateTime.utc(2026, 1, 1);

  // Five records with a sleeve apiece.
  final songs = [
    for (var i = 1; i <= 5; i++)
      entry(
        id: '$i',
        title: 'Song $i',
        artist: 'Artist',
        album: 'Record $i',
        coverId: 'cover-$i',
      ),
  ];

  Playlist stored(
    String id,
    String name, {
    List<MusicEntry> entries = const [],
    String? coverId,
    DateTime? modifiedAt,
  }) => Playlist(
    id: id,
    name: name,
    entries: [
      for (final (index, song) in entries.indexed)
        PlaylistEntry(id: '$id-e$index', path: song.file.path),
    ],
    coverId: coverId,
    createdAt: earlier,
    modifiedAt: modifiedAt ?? earlier,
  );

  final roadTrip = stored('p1', 'Road trip', entries: songs.take(2).toList());

  Harness harnessOver(List<Playlist> playlists) =>
      Harness(library: songs, playlists: playlists, now: now);

  Future<Harness> show(
    WidgetTester tester, {
    List<Playlist> playlists = const [],
    Harness? harness,
  }) async {
    final over = harness ?? harnessOver(playlists);
    await tester.pumpHarness(over, const Scaffold(body: PlaylistsView()));

    return over;
  }

  Future<void> openMenuOf(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byTooltip('Playlist actions'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.widgetWithText(MenuItemButton, item));
    await tester.pumpAndSettle();
  }

  List<String?> sleevesIn(WidgetTester tester) => [
    for (final art in tester.widgetList<AlbumArt>(
      find.descendant(
        of: find.byType(PlaylistCover),
        matching: find.byType(AlbumArt),
      ),
    ))
      art.coverId,
  ];

  group('the list', () {
    testWidgets(
      'GivenNoPlaylists_WhenTheTabIsShown_ThenItSaysSoAndOffersNewPlaylist',
      (tester) async {
        await show(tester);

        expect(find.text('No playlists yet'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'New playlist'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenPlaylists_WhenTheTabIsShown_ThenEachIsARowWithItsNameAndSongCount',
      (tester) async {
        await show(tester, playlists: [roadTrip, stored('p2', 'Empty one')]);

        final row = find.widgetWithText(ListTile, 'Road trip');
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text('2 songs')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.byType(PlaylistCover)),
          findsOneWidget,
        );
        expect(find.text('No songs'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheTilesLayout_WhenTheTabIsShown_ThenEachPlaylistIsATile',
      (tester) async {
        final harness = harnessOver([roadTrip]);
        await harness
            .read(musicLayoutControllerProvider.notifier)
            .choose(MusicLayout.grid);

        await show(tester, harness: harness);

        expect(find.widgetWithText(Card, 'Road trip'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Road trip'), findsNothing);
        expect(
          find.descendant(
            of: find.widgetWithText(Card, 'Road trip'),
            matching: find.byTooltip('Playlist actions'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenRows_WhenTheTilesSwitchIsPicked_ThenTheTabAndTheLibraryShowTiles',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);

        await tester.tap(find.byTooltip('Grid'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(Card, 'Road trip'), findsOneWidget);
        expect(harness.read(musicLayoutControllerProvider), MusicLayout.grid);
      },
    );

    testWidgets(
      'GivenPlaylistsChangedAtDifferentTimes_WhenTheTabIsShown_ThenTheLastChangedIsFirst',
      (tester) async {
        await show(
          tester,
          playlists: [
            stored('p1', 'Oldest', modifiedAt: DateTime.utc(2026, 1, 1)),
            stored('p2', 'Newest', modifiedAt: DateTime.utc(2026, 3, 1)),
            stored('p3', 'Middle', modifiedAt: DateTime.utc(2026, 2, 1)),
          ],
        );

        double top(String name) => tester.getTopLeft(find.text(name)).dy;
        expect(top('Newest'), lessThan(top('Middle')));
        expect(top('Middle'), lessThan(top('Oldest')));
      },
    );

    testWidgets(
      'GivenAStoreThatCouldNotBeRead_WhenTheTabIsShown_ThenItShowsTheFailureAndNoNewPlaylist',
      (tester) async {
        final harness = harnessOver(const []);
        harness.playlistStore.failRead = Exception('unreadable');

        await show(tester, harness: harness);

        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('New playlist'), findsNothing);
        expect(find.text('No playlists yet'), findsNothing);
      },
    );
  });

  group('new playlist', () {
    testWidgets('GivenNoPlaylists_WhenANewOneIsNamed_ThenItIsStoredAndListed', (
      tester,
    ) async {
      final harness = await show(tester);

      await tester.tap(find.text('New playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Road trip ');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
      expect(harness.playlistStore.playlists.single.name, 'Road trip');
    });

    testWidgets(
      'GivenTheNameDialog_WhenABlankNameIsSubmitted_ThenItIsRefusedWithAReason',
      (tester) async {
        final harness = await show(tester);

        await tester.tap(find.text('New playlist'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();

        expect(find.text('Give the playlist a name'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(harness.playlistStore.playlists, isEmpty);
      },
    );

    testWidgets(
      'GivenPlaylists_WhenNewPlaylistIsUsedFromTheTop_ThenTheNewOneIsListedFirst',
      (tester) async {
        await show(tester, playlists: [roadTrip]);

        await tester.tap(find.text('New playlist'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Night drive');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.text('Night drive')).dy,
          lessThan(tester.getTopLeft(find.text('Road trip')).dy),
        );
      },
    );
  });

  group('opening', () {
    testWidgets('GivenAPlaylistRow_WhenItIsTapped_ThenThatPlaylistOpens', (
      tester,
    ) async {
      final harness = await show(
        tester,
        playlists: [roadTrip, stored('p2', 'Night drive')],
      );

      await tester.tap(find.text('Road trip'));
      await tester.pumpAndSettle();

      expect(harness.read(playlistBrowseProvider), 'p1');
      expect(find.text('Road trip'), findsOneWidget);
      expect(find.text('Night drive'), findsNothing);
    });

    testWidgets(
      'GivenAnOpenPlaylist_WhenAllPlaylistsIsPressed_ThenTheListIsBack',
      (tester) async {
        final harness = harnessOver([roadTrip, stored('p2', 'Night drive')]);
        harness.read(playlistBrowseProvider.notifier).open('p1');
        await show(tester, harness: harness);

        await tester.tap(find.byTooltip('All playlists'));
        await tester.pumpAndSettle();

        expect(harness.read(playlistBrowseProvider), isNull);
        expect(find.text('Night drive'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheOpenPlaylistNoLongerExists_WhenTheTabIsShown_ThenTheListIsShown',
      (tester) async {
        final harness = harnessOver([roadTrip]);
        harness.read(playlistBrowseProvider.notifier).open('gone');

        await show(tester, harness: harness);

        expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
        expect(find.byTooltip('All playlists'), findsNothing);
      },
    );
  });

  group('the menu', () {
    testWidgets('GivenAPlaylistRow_WhenItIsRightClicked_ThenItsMenuOpens', (
      tester,
    ) async {
      await show(tester, playlists: [roadTrip]);

      await tester.tap(find.text('Road trip'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MenuItemButton, 'Rename…'), findsOneWidget);
    });

    testWidgets(
      'GivenAPlaylistRow_WhenItIsTouchedAndHeld_ThenItsMenuOpensAndNothingOpens',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);

        await tester.longPress(find.text('Road trip'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(MenuItemButton, 'Rename…'), findsOneWidget);
        expect(harness.read(playlistBrowseProvider), isNull);
      },
    );

    testWidgets(
      'GivenAPlaylistWithoutACustomCover_WhenItsMenuOpens_ThenThereIsNoRemoveCover',
      (tester) async {
        await show(tester, playlists: [roadTrip]);

        await openMenuOf(tester, 'Road trip');

        expect(
          find.widgetWithText(MenuItemButton, 'Choose cover…'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(MenuItemButton, 'Remove cover'),
          findsNothing,
        );
        expect(
          find.widgetWithText(MenuItemButton, 'Export to .m3u…'),
          findsOneWidget,
        );
        expect(find.widgetWithText(MenuItemButton, 'Delete…'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenItIsRenamed_ThenTheRowAndTheStoreHaveTheNewName',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Rename…');
        // Offered with the name it has, to be edited rather than retyped.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Road trip',
        );
        await tester.enterText(find.byType(TextField), 'Night drive');
        await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, 'Night drive'), findsOneWidget);
        expect(harness.playlistStore.playlists.single.name, 'Night drive');
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenAPngIsChosenAsItsCover_ThenTheCoverIsThatPicture',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        final png = base64Decode(onePixelPng);
        harness.coverPicker.next = png;

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Choose cover…');

        expect(harness.playlistCovers.covers['p1'], png);
        expect(harness.playlistStore.playlists.single.coverId, 'p1');
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(PlaylistCover),
            matching: find.byType(Image),
          ),
        );
        expect((image.image as MemoryImage).bytes, png);
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenAGifIsChosenAsItsCover_ThenItIsRefusedAndNothingIsStored',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.coverPicker.next = Uint8List.fromList(utf8.encode('GIF89a..'));

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Choose cover…');

        expect(
          find.text('Choose a JPEG or PNG image for the cover'),
          findsOneWidget,
        );
        expect(harness.playlistCovers.covers, isEmpty);
        expect(harness.playlistStore.playlists.single.coverId, isNull);
      },
    );

    testWidgets(
      'GivenTheCoverDialogDismissed_WhenChooseCoverIsUsed_ThenNothingChanges',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.coverPicker.next = null;

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Choose cover…');

        expect(harness.coverPicker.picks, 1);
        expect(harness.playlistStore.writes, 0);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('GivenACustomCover_WhenRemoveCoverIsUsed_ThenTheMosaicIsBack', (
      tester,
    ) async {
      final harness = harnessOver([
        stored('p1', 'Road trip', entries: songs, coverId: 'p1'),
      ]);
      harness.playlistCovers.covers['p1'] = base64Decode(onePixelPng);
      await show(tester, harness: harness);
      expect(sleevesIn(tester), isEmpty);

      await openMenuOf(tester, 'Road trip');
      await choose(tester, 'Remove cover');

      expect(sleevesIn(tester), ['cover-1', 'cover-2', 'cover-3', 'cover-4']);
      expect(harness.playlistStore.playlists.single.coverId, isNull);
      expect(harness.playlistCovers.covers, isEmpty);
    });

    testWidgets(
      'GivenAPlaylist_WhenItIsExported_ThenTheFileIsOfferedAndWhereItWentIsSaid',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.fileSaver.next = const SavedFile(
          path: '/exports/Road trip.m3u',
        );

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Export to .m3u…');

        expect(harness.fileSaver.saved.single.suggestedName, 'Road trip.m3u');
        expect(
          utf8.decode(harness.fileSaver.saved.single.bytes),
          startsWith('#EXTM3U'),
        );
        expect(find.text('Saved to /exports/Road trip.m3u'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAPlaceWithNoPath_WhenAPlaylistIsExported_ThenThatItWasExportedIsSaid',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        // Android's document provider: a content:// address, not a path.
        harness.fileSaver.next = const SavedFile();

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Export to .m3u…');

        expect(harness.fileSaver.saved, hasLength(1));
        expect(find.text('Playlist exported'), findsOneWidget);
        expect(find.textContaining('Saved to'), findsNothing);
      },
    );

    testWidgets(
      'GivenTheSaveDialogCancelled_WhenAPlaylistIsExported_ThenNothingIsSaid',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.fileSaver.next = null;

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Export to .m3u…');

        expect(harness.fileSaver.saved, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'GivenASaveThatFails_WhenAPlaylistIsExported_ThenTheFailureIsSaid',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.fileSaver.failure = Exception('disk full');

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Export to .m3u…');

        expect(find.text("Couldn't export Road trip"), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenDeleteIsConfirmed_ThenItIsGoneAndTheSongsAreNamedAsKept',
      (tester) async {
        final harness = await show(
          tester,
          playlists: [roadTrip, stored('p2', 'Night drive')],
        );

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Delete…');
        expect(find.text('Delete Road trip?'), findsOneWidget);
        expect(find.text('The songs stay in your library.'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Road trip'), findsNothing);
        expect([for (final p in harness.playlistStore.playlists) p.id], ['p2']);
      },
    );

    testWidgets(
      'GivenTheDeleteQuestion_WhenItIsCancelled_ThenThePlaylistStays',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Delete…');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
        expect(harness.playlistStore.playlists, hasLength(1));
      },
    );

    testWidgets(
      'GivenAWriteThatFails_WhenAPlaylistIsRenamed_ThenTheFailureIsSaidAndTheNameStays',
      (tester) async {
        final harness = await show(tester, playlists: [roadTrip]);
        harness.playlistStore.failNextWrite = Exception('disk full');

        await openMenuOf(tester, 'Road trip');
        await choose(tester, 'Rename…');
        await tester.enterText(find.byType(TextField), 'Night drive');
        await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
        await tester.pumpAndSettle();

        expect(find.text("Couldn't save the playlists"), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
      },
    );
  });
}
