import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlists_view.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// *Add to playlist…*: the five places it is offered, the picker, the
/// duplicate question and what is said afterwards.
void main() {
  final now = DateTime.utc(2026, 6, 1, 12);
  final earlier = DateTime.utc(2026, 1, 1);
  final earliest = DateTime.utc(2025);

  final a = entry(
    id: 'a',
    title: 'Alpha',
    artist: 'Band',
    album: 'First',
    track: 1,
  );
  final b = entry(
    id: 'b',
    title: 'Bravo',
    artist: 'Band',
    album: 'First',
    track: 2,
  );
  final c = entry(
    id: 'c',
    title: 'Charlie',
    artist: 'Band',
    album: 'Second',
    track: 1,
  );
  final d = entry(
    id: 'd',
    title: 'Delta',
    artist: 'Band',
    album: 'Second',
    track: 2,
  );

  // A record of three, in the library out of track order.
  final t3 = entry(
    id: 't3',
    title: 'Third',
    artist: 'Trio',
    album: 'Three',
    track: 3,
  );
  final t1 = entry(
    id: 't1',
    title: 'First of three',
    artist: 'Trio',
    album: 'Three',
    track: 1,
  );
  final t2 = entry(
    id: 't2',
    title: 'Second of three',
    artist: 'Trio',
    album: 'Three',
    track: 2,
  );

  PlaylistEntry inList(String id, MusicEntry song) =>
      PlaylistEntry(id: id, path: song.file.path);

  Playlist playlist(
    String id,
    String name, {
    List<PlaylistEntry> entries = const [],
    DateTime? modifiedAt,
  }) => Playlist(
    id: id,
    name: name,
    entries: entries,
    createdAt: earliest,
    modifiedAt: modifiedAt ?? earlier,
  );

  // Two playlists, the older first in the store.
  final oldest = playlist('p-old', 'Old mix', modifiedAt: earliest);
  final roadTrip = playlist('p-road', 'Road trip');

  Widget area() => const Scaffold(body: MusicLibraryView());

  Future<Harness> musicArea(
    WidgetTester tester, {
    List<MusicEntry>? library,
    List<Playlist>? playlists,
    String tab = 'Songs',
  }) async {
    final harness = Harness(
      library: library ?? [a, b, c, d],
      playlists: playlists ?? [oldest, roadTrip],
      now: now,
    );
    await tester.pumpHarness(harness, area());
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();

    return harness;
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  Finder menuItem(String text) => find.widgetWithText(MenuItemButton, text);

  Future<void> rightClick(WidgetTester tester, String title) async {
    await tester.tap(row(title), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  Future<void> hold(WidgetTester tester, String title) async {
    await tester.longPress(row(title));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) => tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ListTile, name),
    ),
  );

  /// What the picker lists, top to bottom.
  List<String> picked(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ListTile),
      ),
    ))
      (tile.title! as Text).data!,
  ];

  /// The files in the stored playlist [id], in order.
  List<String> stored(Harness harness, String id) => [
    for (final stored in harness.playlistStore.playlists)
      if (stored.id == id)
        for (final entry in stored.entries) entry.path,
  ];

  List<String> pathsOf(List<MusicEntry> songs) => [
    for (final song in songs) song.file.path,
  ];

  /// Opens the picker from Bravo's right-click menu.
  Future<void> openPickerOnBravo(WidgetTester tester) async {
    await rightClick(tester, 'Bravo');
    await tap(tester, menuItem('Add to playlist…'));
  }

  group('the picker', () {
    testWidgets(
      'GivenTwoPlaylists_WhenTheSongMenuAddsToAPlaylist_ThenNewPlaylistIsFirstAndTheMostRecentlyChangedNext',
      (tester) async {
        await musicArea(tester);

        await openPickerOnBravo(tester);

        expect(picked(tester), ['New playlist…', 'Road trip', 'Old mix']);
      },
    );

    testWidgets(
      'GivenThePicker_WhenAPlaylistIsChosen_ThenTheSongIsAddedAtTheEndAndTheSnackbarSaysSo',
      (tester) async {
        final withAlpha = playlist(
          'p-road',
          'Road trip',
          entries: [inList('e1', a)],
        );
        final harness = await musicArea(tester, playlists: [oldest, withAlpha]);
        await openPickerOnBravo(tester);

        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([a, b]));
        expect(find.text('Added 1 song to Road trip'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('GivenThePicker_WhenItIsDismissed_ThenNothingIsWritten', (
      tester,
    ) async {
      final harness = await musicArea(tester);
      await openPickerOnBravo(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(harness.playlistStore.writes, 0);
      expect(find.textContaining('Added'), findsNothing);
    });

    testWidgets(
      'GivenThePicker_WhenNewPlaylistIsChosenAndNamed_ThenItIsMadeAndTheSongIsAddedToIt',
      (tester) async {
        final harness = await musicArea(tester);
        await openPickerOnBravo(tester);

        await choose(tester, 'New playlist…');
        await tester.enterText(find.byType(TextField), 'Fresh');
        await tap(tester, find.widgetWithText(FilledButton, 'Create'));

        final fresh = harness.playlistStore.playlists.singleWhere(
          (stored) => stored.name == 'Fresh',
        );
        expect(pathsOf([b]), [for (final e in fresh.entries) e.path]);
        expect(find.text('Added 1 song to Fresh'), findsOneWidget);
        expect(harness.playlistStore.playlists, hasLength(3));
      },
    );

    testWidgets(
      'GivenThePicker_WhenNewPlaylistIsCancelled_ThenNothingIsMadeOrAdded',
      (tester) async {
        final harness = await musicArea(tester);
        await openPickerOnBravo(tester);

        await choose(tester, 'New playlist…');
        await tap(tester, find.widgetWithText(TextButton, 'Cancel'));

        expect(harness.playlistStore.writes, 0);
        expect(find.textContaining('Added'), findsNothing);
      },
    );

    testWidgets(
      'GivenAStoreThatCannotBeWritten_WhenAPlaylistIsChosen_ThenTheSaveFailureIsSaid',
      (tester) async {
        final harness = await musicArea(tester);
        await openPickerOnBravo(tester);
        harness.playlistStore.failNextWrite = Exception('disk full');

        await choose(tester, 'Road trip');

        expect(find.text("Couldn't save the playlists"), findsOneWidget);
        expect(stored(harness, 'p-road'), isEmpty);
      },
    );
  });

  group('duplicates', () {
    // Road trip holds Bravo already.
    final holdingBravo = playlist(
      'p-road',
      'Road trip',
      entries: [inList('e1', b)],
    );

    testWidgets(
      'GivenTheSongIsAlreadyThere_WhenAPlaylistIsChosen_ThenItAsksWhetherToAddAgain',
      (tester) async {
        final harness = await musicArea(tester, playlists: [holdingBravo]);
        await openPickerOnBravo(tester);

        await choose(tester, 'Road trip');

        expect(find.text('Already in Road trip — add again?'), findsOneWidget);
        expect(find.text('Add anyway'), findsOneWidget);
        expect(find.text('Skip those'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(harness.playlistStore.writes, 0);
      },
    );

    testWidgets(
      'GivenTheQuestion_WhenAddAnywayIsChosen_ThenTheSongIsAddedASecondTime',
      (tester) async {
        final harness = await musicArea(tester, playlists: [holdingBravo]);
        await openPickerOnBravo(tester);
        await choose(tester, 'Road trip');

        await tap(tester, find.text('Add anyway'));

        expect(stored(harness, 'p-road'), pathsOf([b, b]));
        expect(find.text('Added 1 song to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheQuestion_WhenSkipThoseIsChosenAndNothingElseWasPicked_ThenNothingIsAddedAndNothingIsWritten',
      (tester) async {
        final harness = await musicArea(tester, playlists: [holdingBravo]);
        await openPickerOnBravo(tester);
        await choose(tester, 'Road trip');

        await tap(tester, find.text('Skip those'));

        expect(stored(harness, 'p-road'), pathsOf([b]));
        expect(harness.playlistStore.writes, 0);
        expect(find.text('Nothing added'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheQuestion_WhenCancelIsChosen_ThenNothingIsAddedOrSaid',
      (tester) async {
        final harness = await musicArea(tester, playlists: [holdingBravo]);
        await openPickerOnBravo(tester);
        await choose(tester, 'Road trip');

        await tap(tester, find.widgetWithText(TextButton, 'Cancel'));

        expect(stored(harness, 'p-road'), pathsOf([b]));
        expect(harness.playlistStore.writes, 0);
        expect(find.textContaining('Added'), findsNothing);
        expect(find.text('Nothing added'), findsNothing);
      },
    );

    testWidgets(
      'GivenTwoPickedAndOneAlreadyThere_WhenSkipThoseIsChosen_ThenOnlyTheOtherIsAddedAndCounted',
      (tester) async {
        final harness = await musicArea(tester, playlists: [holdingBravo]);
        await hold(tester, 'Delta');
        await tap(tester, row('Bravo'));
        await tap(tester, find.byTooltip('Add to playlist…'));
        await choose(tester, 'Road trip');

        await tap(tester, find.text('Skip those'));

        expect(stored(harness, 'p-road'), pathsOf([b, d]));
        expect(find.text('Added 1 song to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenNoneOfThemIsThere_WhenAPlaylistIsChosen_ThenItIsNotAsked',
      (tester) async {
        await musicArea(tester, playlists: [holdingBravo]);
        await rightClick(tester, 'Alpha');
        await tap(tester, menuItem('Add to playlist…'));

        await choose(tester, 'Road trip');

        expect(find.textContaining('Already in'), findsNothing);
        expect(find.text('Added 1 song to Road trip'), findsOneWidget);
      },
    );
  });

  group('the places it is offered', () {
    testWidgets(
      'GivenASongRow_WhenItsMenuIsOpened_ThenAddToPlaylistIsOffered',
      (tester) async {
        await musicArea(tester);

        await rightClick(tester, 'Charlie');

        expect(menuItem('Add to playlist…'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenASongRow_WhenItsMoreButtonAddsToAPlaylist_ThenThatSongIsAdded',
      (tester) async {
        final harness = await musicArea(tester);

        await tap(
          tester,
          find.descendant(
            of: find
                .ancestor(of: row('Charlie'), matching: find.byType(Row))
                .first,
            matching: find.byTooltip('Actions for this track'),
          ),
        );
        await tap(tester, menuItem('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([c]));
      },
    );

    testWidgets(
      'GivenAThirdAndAFirstPicked_WhenTheBarAddsToAPlaylist_ThenTheyAreAddedInListOrder',
      (tester) async {
        final harness = await musicArea(tester);
        await hold(tester, 'Delta');
        await tap(tester, row('Bravo'));

        await tap(tester, find.byTooltip('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([b, d]));
        expect(find.text('Added 2 songs to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenSongsPicked_WhenTheirRightClickMenuAddsToAPlaylist_ThenThePickedAreAddedInListOrder',
      (tester) async {
        final harness = await musicArea(tester);
        await hold(tester, 'Delta');
        await tap(tester, row('Bravo'));

        await rightClick(tester, 'Delta');
        await tap(tester, menuItem('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([b, d]));
      },
    );

    testWidgets(
      'GivenAnAlbumOfThree_WhenItsMenuAddsToAPlaylist_ThenAllThreeAreAddedInTrackOrder',
      (tester) async {
        final harness = await musicArea(
          tester,
          library: [t3, t1, t2, a],
          tab: 'Albums',
        );

        await hold(tester, 'Three');
        await tap(tester, menuItem('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([t1, t2, t3]));
        expect(find.text('Added 3 songs to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnArtist_WhenTheirMenuAddsToAPlaylist_ThenTheirTracksAreAddedRecordByRecord',
      (tester) async {
        final harness = await musicArea(
          tester,
          library: [d, c, b, a, t1],
          tab: 'Artists',
        );

        await hold(tester, 'Band');
        await tap(tester, menuItem('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([a, b, c, d]));
        expect(find.text('Added 4 songs to Road trip'), findsOneWidget);
      },
    );
  });

  group('inside a playlist', () {
    // Bravo, Alpha, a file the library no longer has, Bravo again.
    final mixed = playlist(
      'p-mix',
      'Mixed',
      entries: [
        inList('m1', b),
        inList('m2', a),
        const PlaylistEntry(id: 'm3', path: '/library/zzz-ghost.flac'),
        inList('m4', b),
      ],
      modifiedAt: now,
    );

    Future<Harness> inside(WidgetTester tester) async {
      final harness = Harness(
        library: [a, b, c, d],
        playlists: [mixed, roadTrip],
        now: now,
      );
      harness.read(playlistBrowseProvider.notifier).open(mixed.id);
      await tester.pumpHarness(harness, const Scaffold(body: PlaylistsView()));

      return harness;
    }

    testWidgets(
      'GivenEntriesTicked_WhenTheBarAddsToAPlaylist_ThenThePresentSongsAreAddedOnceEachInPlaylistOrder',
      (tester) async {
        final harness = await inside(tester);
        await tester.longPress(row('Bravo').first);
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('Select all'));

        await tap(tester, find.byTooltip('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([b, a]));
        expect(find.text('Added 2 songs to Road trip'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenEntriesTicked_WhenTheirRightClickMenuAddsToAPlaylist_ThenThePresentSongsAreAdded',
      (tester) async {
        final harness = await inside(tester);
        await tester.longPress(row('Alpha'));
        await tester.pumpAndSettle();

        await tester.tap(row('Alpha'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        await tap(tester, menuItem('Add to playlist…'));
        await choose(tester, 'Road trip');

        expect(stored(harness, 'p-road'), pathsOf([a]));
      },
    );

    testWidgets(
      'GivenOnlyAMissingEntryTicked_WhenTheBarIsShown_ThenAddToPlaylistDoesNothing',
      (tester) async {
        final harness = await inside(tester);
        await tester.longPress(row('Missing').first);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Add to playlist…'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(harness.playlistStore.writes, 0);
      },
    );
  });
}
