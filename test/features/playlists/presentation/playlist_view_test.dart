import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/app.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/autofill/presentation/autofill_screen.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';
import 'package:orpheus/features/playback/presentation/music_rows.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlist_cover.dart';
import 'package:orpheus/features/playlists/presentation/playlists_view.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Inside a playlist: its header, its rows present and missing, playing it,
/// reordering it, and picking songs in it.
void main() {
  final now = DateTime.utc(2026, 6, 1, 12);
  final made = DateTime.utc(2026);

  final a = entry(
    id: 'a',
    title: 'Alpha',
    artist: 'Band',
    album: 'First',
    duration: const Duration(minutes: 3),
  );
  final b = entry(
    id: 'b',
    title: 'Bravo',
    artist: 'Band',
    album: 'First',
    duration: const Duration(minutes: 4),
  );
  final c = entry(
    id: 'c',
    title: 'Charlie',
    artist: 'Band',
    album: 'Second',
    duration: const Duration(minutes: 5),
  );

  /// [song] in a playlist as [id], with a snapshot older than the catalog:
  /// a row that showed the snapshot instead of the catalog would say so.
  PlaylistEntry at(String id, MusicEntry song) => PlaylistEntry(
    id: id,
    path: song.file.path,
    title: 'Old ${song.title}',
    artist: 'Old artist',
    duration: song.duration,
  );

  // A song the library no longer has: what is left of it is the snapshot.
  const ghost = PlaylistEntry(
    id: 'e2',
    path: '/library/zzz-ghost.flac',
    title: 'Ghost',
    artist: 'Old Band',
    duration: Duration(minutes: 2),
  );

  Playlist playlist(String id, String name, List<PlaylistEntry> entries) =>
      Playlist(
        id: id,
        name: name,
        entries: entries,
        createdAt: made,
        modifiedAt: made,
      );

  // Alpha, Ghost (missing), Bravo, Charlie.
  final roadTrip = playlist('p1', 'Road trip', [
    at('e1', a),
    ghost,
    at('e3', b),
    at('e4', c),
  ]);

  // Alpha twice, Bravo between.
  final twice = playlist('p1', 'Road trip', [
    at('d1', a),
    at('d2', b),
    at('d3', a),
  ]);

  /// The Playlists tab with [open] open, shuffling with [shuffleSeed].
  Future<Harness> show(
    WidgetTester tester,
    Playlist open, {
    int shuffleSeed = 7,
  }) async {
    final harness = Harness(
      library: [a, b, c],
      playlists: [open],
      now: now,
      shuffleSeed: shuffleSeed,
    );
    for (final song in [a, b, c]) {
      harness.tagWriter.files[song.file.path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: const {AutofillField.artist: 'Band'},
      );
    }
    harness.read(playlistBrowseProvider.notifier).open(open.id);
    await tester.pumpHarness(harness, const Scaffold(body: PlaylistsView()));

    return harness;
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  Future<void> hold(WidgetTester tester, Finder target) async {
    await tester.longPress(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder menuItem(String text) => find.widgetWithText(MenuItemButton, text);

  /// The ⋮ button of the row [target].
  Finder moreOf(Finder target) => find.descendant(
    of: find.ancestor(of: target, matching: find.byType(Row)).first,
    matching: find.byTooltip('Actions for this track'),
  );

  /// Where the drag handle of the row titled [title] is: the one level with
  /// that row.
  Offset handleOf(WidgetTester tester, String title) {
    final band = tester.getRect(row(title));
    final handles = find.byIcon(Icons.drag_handle);
    for (var index = 0; index < handles.evaluate().length; index++) {
      final centre = tester.getCenter(handles.at(index));
      if (centre.dy > band.top && centre.dy < band.bottom) return centre;
    }
    throw StateError('No handle beside $title');
  }

  List<String> titlesInOrder(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  List<String> queued(Harness harness) => [
    for (final track
        in harness.read(audioPlaybackControllerProvider).queue.tracks)
      track.path,
  ];

  List<String> storedIds(Harness harness) => [
    for (final entry in harness.playlistStore.playlists.single.entries)
      entry.id,
  ];

  Set<String> selected(Harness harness) =>
      harness.read(songSelectionProvider).paths;

  /// Drags the row titled [title] by its handle until it is over the row
  /// titled [over].
  Future<void> dragOnto(WidgetTester tester, String title, String over) async {
    final from = handleOf(tester, title);
    final to = tester.getTopLeft(row(over)).dy;
    final gesture = await tester.startGesture(from);
    await tester.pump();
    // In steps, as a hand moves, so the list sees the row travel.
    final distance = to - from.dy - 4;
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(from + Offset(0, distance * step / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('what is shown', () {
    testWidgets(
      'GivenPresentAndMissingEntries_WhenThePlaylistIsOpen_ThenTheRowsShowInOrderAndTheMissingOneSaysSo',
      (tester) async {
        await show(tester, roadTrip);

        expect(titlesInOrder(tester), ['Alpha', 'Ghost', 'Bravo', 'Charlie']);
        // The catalog's current tags for a present song, not the snapshot.
        expect(find.text('Old Alpha'), findsNothing);
        expect(
          find.descendant(
            of: row('Ghost'),
            matching: find.text('Missing · Old Band'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row('Bravo'), matching: find.text('Band')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GivenAMissingEntry_WhenThePlaylistIsOpen_ThenOnlyItsRowIsGreyed',
      (tester) async {
        await show(tester, roadTrip);

        final greyed = Theme.of(tester.element(row('Ghost'))).disabledColor;
        expect(tester.widget<ListTile>(row('Ghost')).textColor, greyed);
        expect(tester.widget<ListTile>(row('Alpha')).textColor, isNull);
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenItIsOpen_ThenTheHeaderShowsItsCoverNameCountAndLength',
      (tester) async {
        await show(tester, roadTrip);

        expect(find.text('Road trip'), findsOneWidget);
        expect(find.byType(PlaylistCover), findsOneWidget);
        // 3 + 2 + 4 + 5 minutes; the missing song's from its snapshot.
        expect(find.text('4 songs · 14:00'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
        expect(find.text('Shuffle'), findsOneWidget);
        expect(find.byTooltip('Playlist actions'), findsOneWidget);
      },
    );

    testWidgets('GivenAnEmptyPlaylist_WhenItIsOpen_ThenItSaysSoAndPlayIsOff', (
      tester,
    ) async {
      await show(tester, playlist('p1', 'Road trip', const []));

      expect(find.text('No songs in this playlist yet'), findsOneWidget);
      final play = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Play'),
      );
      expect(play.onPressed, isNull);
    });

    testWidgets(
      'GivenAnOpenPlaylist_WhileTheLibraryLoads_ThenItShowsLoadingNotMissing',
      (tester) async {
        final harness = await show(tester, roadTrip);

        final gate = harness.catalogs.readGate = Completer<void>();
        harness.container.invalidate(
          musicLibraryControllerProvider,
          asReload: true,
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('Missing'), findsNothing);
        expect(row('Alpha'), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        expect(titlesInOrder(tester), ['Alpha', 'Ghost', 'Bravo', 'Charlie']);
      },
    );
  });

  group('playing', () {
    testWidgets(
      'GivenAPlaylist_WhenARowIsTapped_ThenItPlaysFromThatEntryOnSkippingTheMissing',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await tap(tester, row('Alpha'));

        expect(queued(harness), [a.file.path, b.file.path, c.file.path]);
        final queue = harness.read(audioPlaybackControllerProvider).queue;
        expect(queue.kind, QueueKind.playlist);
        expect(queue.label, 'Road trip');
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenALaterRowIsTapped_ThenWhatIsBeforeItIsLeftOut',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await tap(tester, row('Bravo'));

        expect(queued(harness), [b.file.path, c.file.path]);
      },
    );

    testWidgets('GivenAMissingRow_WhenItIsTapped_ThenNothingPlays', (
      tester,
    ) async {
      final harness = await show(tester, roadTrip);

      await tap(tester, row('Ghost'));

      expect(queued(harness), isEmpty);
    });

    testWidgets(
      'GivenAPlaylist_WhenPlayIsPressed_ThenEveryPresentSongPlaysFromTheFirst',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await tap(tester, find.widgetWithText(FilledButton, 'Play'));

        expect(queued(harness), [a.file.path, b.file.path, c.file.path]);
        expect(
          harness.read(audioPlaybackControllerProvider).queue.label,
          'Road trip',
        );
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenShuffleIsPressed_ThenEveryPresentSongIsQueuedShuffled',
      (tester) async {
        const seed = 3;
        final harness = await show(tester, roadTrip, shuffleSeed: seed);

        await tap(tester, find.text('Shuffle'));

        final inOrder = [a.file.path, b.file.path, c.file.path];
        final shuffled = [...inOrder]..shuffle(Random(seed));
        // A seed whose shuffle is the playlist's own order would prove nothing.
        expect(shuffled, isNot(inOrder));
        expect(queued(harness), shuffled);
        expect(
          harness.read(audioPlaybackControllerProvider).queue.label,
          'Road trip',
        );
      },
    );
  });

  group('reordering', () {
    testWidgets(
      'GivenAPlaylist_WhenARowIsDraggedByItsHandle_ThenItMovesAndIsSaved',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await dragOnto(tester, 'Charlie', 'Alpha');

        expect(storedIds(harness), ['e4', 'e1', 'e2', 'e3']);
        expect(titlesInOrder(tester), ['Charlie', 'Alpha', 'Ghost', 'Bravo']);
      },
    );

    testWidgets('GivenAPlaylist_WhenARowIsDraggedDown_ThenItMovesAndIsSaved', (
      tester,
    ) async {
      final harness = await show(tester, roadTrip);

      await dragOnto(tester, 'Alpha', 'Charlie');

      expect(storedIds(harness), ['e2', 'e3', 'e1', 'e4']);
      expect(titlesInOrder(tester), ['Ghost', 'Bravo', 'Alpha', 'Charlie']);
    });

    testWidgets(
      'GivenAMoveThatCannotBeSaved_WhenARowIsDragged_ThenTheStoredOrderIsBack',
      (tester) async {
        final harness = await show(tester, roadTrip);
        harness.playlistStore.failNextWrite = Exception('disk full');

        await dragOnto(tester, 'Charlie', 'Alpha');

        expect(storedIds(harness), ['e1', 'e2', 'e3', 'e4']);
        expect(titlesInOrder(tester), ['Alpha', 'Ghost', 'Bravo', 'Charlie']);
        expect(find.text("Couldn't save the playlists"), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTwoQuickDrops_WhenTheFirstIsSaved_ThenTheSecondStaysOnScreen',
      (tester) async {
        final harness = await show(tester, roadTrip);
        final store = harness.playlistStore..holdWrites = true;

        await dragOnto(tester, 'Charlie', 'Alpha');
        await dragOnto(tester, 'Bravo', 'Charlie');
        const both = ['Bravo', 'Charlie', 'Alpha', 'Ghost'];
        expect(titlesInOrder(tester), both);

        store.heldWrites.removeAt(0).complete();
        await tester.pumpAndSettle();
        expect(storedIds(harness), ['e4', 'e1', 'e2', 'e3']);
        expect(titlesInOrder(tester), both);

        store.heldWrites.removeAt(0).complete();
        await tester.pumpAndSettle();
        expect(storedIds(harness), ['e3', 'e4', 'e1', 'e2']);
        expect(titlesInOrder(tester), both);
      },
    );

    testWidgets(
      'GivenAFailedDropAndAQuickSecond_WhenBothAreDone_ThenTheSecondMovedItsRow',
      (tester) async {
        final harness = await show(tester, roadTrip);
        final store = harness.playlistStore
          ..holdWrites = true
          ..failNextWrite = Exception('disk full');

        // Charlie to the top, and before that is saved, Alpha back above it.
        await dragOnto(tester, 'Charlie', 'Alpha');
        await dragOnto(tester, 'Alpha', 'Charlie');

        store.heldWrites.removeAt(0).complete();
        await tester.pumpAndSettle();
        store.heldWrites.removeAt(0).complete();
        await tester.pumpAndSettle();

        // Alpha went before Charlie in the stored order, where Charlie never
        // left the end: it is Alpha that moved, not the row in its old place.
        expect(storedIds(harness), ['e2', 'e3', 'e1', 'e4']);
        expect(titlesInOrder(tester), ['Ghost', 'Bravo', 'Alpha', 'Charlie']);
      },
    );

    testWidgets(
      'GivenAPlaylist_WhenARowIsHeld_ThenItIsSelectedRatherThanDragged',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await hold(tester, row('Bravo'));

        expect(selected(harness), {'e3'});
        expect(harness.read(songSelectionProvider).scope, ('playlist', 'p1'));
        expect(find.text('1 selected'), findsOneWidget);
        expect(harness.playlistStore.writes, 0);
        expect(queued(harness), isEmpty);
      },
    );

    testWidgets(
      'GivenASelection_WhenARowIsDraggedByItsHandle_ThenNothingMoves',
      (tester) async {
        final harness = await show(tester, roadTrip);
        await hold(tester, row('Bravo'));

        await dragOnto(tester, 'Charlie', 'Alpha');

        expect(harness.playlistStore.writes, 0);
        expect(titlesInOrder(tester), ['Alpha', 'Ghost', 'Bravo', 'Charlie']);
      },
    );
  });

  group('selecting', () {
    testWidgets(
      'GivenASongTwiceInAPlaylist_WhenOneCopyIsHeld_ThenOnlyThatCopyIsTicked',
      (tester) async {
        final harness = await show(tester, twice);

        await hold(tester, row('Alpha').at(1));

        expect(selected(harness), {'d3'});
        final boxes = tester.widgetList<Checkbox>(
          find.descendant(of: row('Alpha'), matching: find.byType(Checkbox)),
        );
        expect([for (final box in boxes) box.value], [false, true]);
        expect(find.text('1 selected'), findsOneWidget);
      },
    );

    testWidgets('GivenNothingSelected_WhenARowIsCtrlClicked_ThenItIsSelected', (
      tester,
    ) async {
      final harness = await show(tester, roadTrip);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row('Ghost'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(selected(harness), {'e2'});
      expect(queued(harness), isEmpty);
    });

    testWidgets(
      'GivenAlphaSelected_WhenBravoIsShiftClicked_ThenAlphaThroughBravoAreSelected',
      (tester) async {
        final harness = await show(tester, roadTrip);
        await hold(tester, row('Alpha'));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(row('Bravo'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        expect(selected(harness), {'e1', 'e2', 'e3'});
        expect(find.text('3 selected'), findsOneWidget);
      },
    );

    testWidgets('GivenASelection_WhenEscapeIsPressed_ThenItEnds', (
      tester,
    ) async {
      final harness = await show(tester, roadTrip);
      await hold(tester, row('Alpha'));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(selected(harness), isEmpty);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets(
      'GivenTwoTicked_WhenRemoveFromPlaylistInTheBarIsPressed_ThenExactlyThoseEntriesGo',
      (tester) async {
        final harness = await show(tester, twice);
        await hold(tester, row('Alpha').at(0));
        await tap(tester, row('Bravo'));

        await tap(tester, find.byTooltip('Remove from playlist'));

        expect(storedIds(harness), ['d3']);
        expect(selected(harness), isEmpty);
        expect(titlesInOrder(tester), ['Alpha']);
      },
    );

    testWidgets(
      'GivenEverythingTicked_WhenEditTagsIsPressed_ThenTheFormOpensOverThePresentSongsOnceEachInPlaylistOrder',
      (tester) async {
        await show(
          tester,
          playlist('p1', 'Road trip', [
            at('x1', b),
            ghost,
            at('x3', a),
            at('x4', b),
          ]),
        );
        await hold(tester, row('Ghost'));
        await tap(tester, find.byTooltip('Select all'));

        await tap(tester, find.widgetWithText(FilledButton, 'Edit tags…'));

        final dialog = tester.widget<EditManyTagsDialog>(
          find.byType(EditManyTagsDialog),
        );
        expect(
          [for (final song in dialog.entries) song.file.path],
          [b.file.path, a.file.path],
        );
        expect(find.text('Selected songs · 2 songs'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenOnlyAMissingRowTicked_WhenTheBarShows_ThenEditTagsIsOff',
      (tester) async {
        await show(tester, roadTrip);

        await hold(tester, row('Ghost'));

        final edit = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Edit tags…'),
        );
        expect(edit.onPressed, isNull);
      },
    );

    testWidgets(
      'GivenTwoTicked_WhenATickedRowIsRightClicked_ThenTheMenuIsForTheSelection',
      (tester) async {
        final harness = await show(tester, roadTrip);
        await hold(tester, row('Alpha'));
        await tap(tester, row('Ghost'));

        await tester.tap(row('Ghost'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(menuItem('Edit tags of 1 song…'), findsOneWidget);
        expect(menuItem('Play'), findsNothing);

        await tap(tester, menuItem('Remove from playlist'));

        expect(storedIds(harness), ['e3', 'e4']);
      },
    );

    testWidgets(
      'GivenA360WidePhoneInPortuguese_WhenARowIsHeld_ThenTheBarFitsWithEveryAction',
      (tester) async {
        final harness = Harness(library: [a, b, c], playlists: [roadTrip]);
        harness.read(playlistBrowseProvider.notifier).open('p1');
        await tester.pumpHarness(
          harness,
          const Scaffold(body: PlaylistsView()),
          window: const Size(360, 800),
          locale: const Locale('pt'),
        );

        await hold(tester, row('Alpha'));

        expect(tester.takeException(), isNull);
        expect(find.text('1 selecionada'), findsOneWidget);
        expect(find.byTooltip('Selecionar tudo'), findsOneWidget);
        expect(find.byTooltip('Remover da playlist'), findsOneWidget);
        // An icon on a phone, where the words would push the count out.
        expect(find.byTooltip('Editar tags…'), findsOneWidget);
      },
    );
  });

  group('autofill', () {
    testWidgets(
      'GivenTwoPresentSongsTicked_WhenAutofillInTheBarIsTapped_ThenTheBatchConfirmationOpens',
      (tester) async {
        final harness = await show(tester, roadTrip);
        await hold(tester, row('Alpha'));
        await tap(tester, row('Bravo'));

        await tap(tester, find.byTooltip('Autofill tags…'));
        await tap(tester, find.text('Find'));

        expect(find.text('Autofill 2 songs?'), findsOneWidget);
        expect(selected(harness), {'e1', 'e3'});
      },
    );

    testWidgets(
      'GivenOneSongTicked_WhenAutofillInTheBarIsTapped_ThenTheLoneTrackReviewOpens',
      (tester) async {
        await show(tester, roadTrip);
        await hold(tester, row('Alpha'));

        await tap(tester, find.byTooltip('Autofill tags…'));
        await tap(tester, find.text('Find'));

        final screen = tester.widget<AutofillScreen>(
          find.byType(AutofillScreen),
        );
        expect(screen.kind, AutofillKind.track);
        expect(
          [for (final song in screen.entries) song.file.path],
          [a.file.path],
        );
      },
    );

    testWidgets(
      'GivenOnlyAMissingRowTicked_WhenTheBarShows_ThenAutofillIsOff',
      (tester) async {
        await show(tester, roadTrip);

        await hold(tester, row('Ghost'));

        final autofill = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.auto_fix_high_outlined),
        );
        expect(autofill.onPressed, isNull);
      },
    );
  });

  group('the song menu', () {
    testWidgets(
      'GivenAPresentRow_WhenRemoveFromPlaylistIsChosen_ThenThatEntryGoes',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await tap(tester, moreOf(row('Bravo')));
        expect(menuItem('Play'), findsOneWidget);
        expect(menuItem('Edit tags…'), findsOneWidget);
        await tap(tester, menuItem('Remove from playlist'));

        expect(storedIds(harness), ['e1', 'e2', 'e4']);
        expect(row('Bravo'), findsNothing);
      },
    );

    testWidgets(
      'GivenAMissingRow_WhenRemoveFromPlaylistIsChosen_ThenThatEntryGoes',
      (tester) async {
        final harness = await show(tester, roadTrip);

        await tap(tester, moreOf(row('Ghost')));
        // Nothing to play or to tag: the file is not in the library.
        expect(menuItem('Play'), findsNothing);
        await tap(tester, menuItem('Remove from playlist'));

        expect(storedIds(harness), ['e1', 'e3', 'e4']);
      },
    );

    testWidgets(
      'GivenACopyOfASongTwice_WhenOneIsRemovedFromItsMenu_ThenTheOtherStays',
      (tester) async {
        final harness = await show(tester, twice);

        await tap(tester, moreOf(row('Alpha').at(1)));
        await tap(tester, menuItem('Remove from playlist'));

        expect(storedIds(harness), ['d1', 'd2']);
      },
    );
  });

  group('back', () {
    testWidgets(
      'GivenASelectionInAnOpenPlaylist_WhenBackIsPressedTwice_ThenTheSelectionEndsThenTheListIsBack',
      (tester) async {
        final harness = Harness(library: [a, b, c], playlists: [roadTrip]);
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
        harness.read(playlistBrowseProvider.notifier).open('p1');
        await tester.pumpAndSettle();
        await hold(tester, row('Bravo'));
        expect(selected(harness), {'e3'});

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(selected(harness), isEmpty);
        expect(harness.read(playlistBrowseProvider), 'p1');
        expect(row('Bravo'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(harness.read(playlistBrowseProvider), isNull);
        expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'GivenAnOpenPlaylist_WhenAllPlaylistsIsPressed_ThenTheListIsBack',
    (tester) async {
      final harness = await show(tester, roadTrip);

      await tap(tester, find.byTooltip('All playlists'));

      expect(harness.read(playlistBrowseProvider), isNull);
      expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
      expect(find.byType(MusicRowMenu), findsNothing);
    },
  );
}
