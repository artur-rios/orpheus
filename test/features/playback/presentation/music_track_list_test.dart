import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Selecting several songs in a song list: how it starts, what a tap does
/// while it lasts, the bar above the rows, and what ends it.
void main() {
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

  Widget area() => const Scaffold(body: MusicLibraryView());

  /// The Music area on Songs, listing the four songs.
  Future<Harness> songs(WidgetTester tester) async {
    final harness = Harness(library: [a, b, c, d]);
    await tester.pumpHarness(harness, area());
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    return harness;
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  Future<void> hold(WidgetTester tester, String title) async {
    await tester.longPress(row(title));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String title) async {
    await tester.tap(row(title));
    await tester.pumpAndSettle();
  }

  Future<void> tapHolding(
    WidgetTester tester,
    LogicalKeyboardKey key,
    String title,
  ) async {
    await tester.sendKeyDownEvent(key);
    await tester.tap(row(title));
    await tester.sendKeyUpEvent(key);
    await tester.pumpAndSettle();
  }

  List<String> queued(Harness harness) => [
    for (final track
        in harness.read(audioPlaybackControllerProvider).queue.tracks)
      track.path,
  ];

  Set<String> selected(Harness harness) =>
      harness.read(songSelectionProvider).paths;

  testWidgets('GivenNothingSelected_WhenARowIsTapped_ThenItPlays', (
    tester,
  ) async {
    final harness = await songs(tester);

    await tap(tester, 'Bravo');

    expect(queued(harness), [b.file.path]);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets(
    'GivenNothingSelected_WhenARowIsHeld_ThenItIsSelectedAndTheBarSays1Selected',
    (tester) async {
      final harness = await songs(tester);

      await hold(tester, 'Bravo');

      expect(selected(harness), {b.file.path});
      expect(find.text('1 selected'), findsOneWidget);
      expect(queued(harness), isEmpty);
    },
  );

  testWidgets(
    'GivenOneSelected_WhenAnotherRowIsTapped_ThenItIsSelectedAndNothingPlays',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');

      await tap(tester, 'Charlie');

      expect(selected(harness), {a.file.path, c.file.path});
      expect(find.text('2 selected'), findsOneWidget);
      expect(queued(harness), isEmpty);
    },
  );

  testWidgets(
    'GivenASelectedRow_WhenItsTickBoxIsTapped_ThenItIsDeselectedAndSelectingEnds',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');

      await tester.tap(
        find.descendant(of: row('Alpha'), matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();

      expect(selected(harness), isEmpty);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('selected'), findsNothing);
    },
  );

  testWidgets(
    'GivenSelecting_WhenTheRowsAreShown_ThenEachTickBoxIsLabelledWithItsSong',
    (tester) async {
      await songs(tester);

      await hold(tester, 'Alpha');

      final box = tester.widget<Checkbox>(
        find.descendant(of: row('Delta'), matching: find.byType(Checkbox)),
      );
      expect(box.semanticLabel, 'Select Delta');
      expect(box.value, isFalse);
    },
  );

  testWidgets('GivenNothingSelected_WhenARowIsCtrlClicked_ThenItIsSelected', (
    tester,
  ) async {
    final harness = await songs(tester);

    await tapHolding(tester, LogicalKeyboardKey.controlLeft, 'Charlie');

    expect(selected(harness), {c.file.path});
    expect(find.text('1 selected'), findsOneWidget);
    expect(queued(harness), isEmpty);
  });

  testWidgets('GivenBSelected_WhenDIsShiftClicked_ThenBThroughDAreSelected', (
    tester,
  ) async {
    final harness = await songs(tester);
    await hold(tester, 'Bravo');

    await tapHolding(tester, LogicalKeyboardKey.shiftLeft, 'Delta');

    expect(selected(harness), {b.file.path, c.file.path, d.file.path});
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets(
    'GivenSomeSelected_WhenSelectAllIsPressed_ThenAllFourAreSelectedAndSelectAllIsGone',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Bravo');

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(selected(harness), hasLength(4));
      expect(find.text('4 selected'), findsOneWidget);
      expect(find.text('Select all'), findsNothing);
    },
  );

  testWidgets('GivenASelection_WhenStopSelectingIsPressed_ThenTheBarIsGone', (
    tester,
  ) async {
    final harness = await songs(tester);
    await hold(tester, 'Bravo');

    await tester.tap(find.byTooltip('Stop selecting'));
    await tester.pumpAndSettle();

    expect(selected(harness), isEmpty);
    expect(find.text('1 selected'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('GivenASelection_WhenEscapeIsPressed_ThenTheBarIsGone', (
    tester,
  ) async {
    final harness = await songs(tester);
    await hold(tester, 'Bravo');
    expect(find.text('1 selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(selected(harness), isEmpty);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets(
    'GivenASelectionInSongs_WhenAnAlbumIsOpened_ThenNothingIsSelectedThere',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');
      expect(find.text('1 selected'), findsOneWidget);

      // Straight from Songs into a record: the same list is drawn again with
      // another record's tracks, so only its identity can tell them apart.
      harness
          .read(musicBrowseControllerProvider.notifier)
          .openAlbum('First', 'Band');
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      expect(harness.read(songSelectionProvider).isActive, isFalse);
    },
  );

  testWidgets(
    'GivenASelectionInAnAlbum_WhenAnotherAlbumIsOpened_ThenNothingIsSelectedThere',
    (tester) async {
      final harness = await songs(tester);
      final navigator = harness.read(musicBrowseControllerProvider.notifier);
      navigator.openAlbum('First', 'Band');
      await tester.pumpAndSettle();
      await hold(tester, 'Alpha');
      expect(find.text('1 selected'), findsOneWidget);

      navigator.openAlbum('Second', 'Band');
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      expect(harness.read(songSelectionProvider).isActive, isFalse);
    },
  );

  testWidgets(
    'GivenASelection_WhenTheSongsChangeInTheSameList_ThenOnlyTheVanishedSongDrops',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');
      await tap(tester, 'Bravo');

      harness
          .read(musicLibraryControllerProvider.notifier)
          .replaceWith(
            MusicCatalog(
              entries: albumArtistsAcross([a, c, d]),
              scannedAt: DateTime.utc(2026),
            ),
          );
      await tester.pumpAndSettle();

      expect(selected(harness), {a.file.path});
      expect(find.text('1 selected'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNothingSelected_WhenASongRowIsHeld_ThenItsMenuDoesNotOpen',
    (tester) async {
      await songs(tester);

      await hold(tester, 'Bravo');

      expect(find.text('Edit tags…'), findsNothing);
      expect(find.text('Play the album'), findsNothing);
    },
  );

  testWidgets('GivenAnAlbumRow_WhenHeld_ThenItsMenuOpens', (tester) async {
    final harness = Harness(library: [a, b, c, d]);
    await tester.pumpHarness(harness, area());
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    await hold(tester, 'First');

    expect(find.text('Edit tags…'), findsOneWidget);
    expect(find.text('Autofill tags…'), findsOneWidget);
  });
}
