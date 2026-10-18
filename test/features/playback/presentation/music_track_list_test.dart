import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playback/presentation/music_rows.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
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
    'GivenTwelveSelectedOnA360WidePhoneInPortuguese_WhenTheBarShows_ThenNothingOverflowsAndTheCountIsShown',
    (tester) async {
      final many = [
        for (var i = 1; i <= 12; i++)
          entry(
            id: 'song$i',
            title: 'Canção $i',
            artist: 'Band',
            album: 'First',
            track: i,
          ),
      ];
      final harness = Harness(library: many);
      await tester.pumpHarness(
        harness,
        area(),
        window: const Size(360, 800),
        locale: const Locale('pt'),
      );
      await tester.tap(find.text('Faixas'));
      await tester.pumpAndSettle();
      await tester.longPress(row('Canção 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Selecionar tudo'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(selected(harness), hasLength(12));
      expect(find.text('12 selecionadas'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Editar tags…'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenBSelected_WhenDsTickBoxIsShiftClicked_ThenBThroughDAreSelected',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Bravo');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(
        find.descendant(of: row('Delta'), matching: find.byType(Checkbox)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(selected(harness), {b.file.path, c.file.path, d.file.path});
      expect(find.text('3 selected'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSomeSelected_WhenSelectAllIsPressed_ThenAllFourAreSelectedAndSelectAllIsGone',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Bravo');

      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      expect(selected(harness), hasLength(4));
      expect(find.text('4 selected'), findsOneWidget);
      expect(find.byTooltip('Select all'), findsNothing);
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
    'GivenASelectionInSongs_WhenAlbumsIsShownAndSongsAgain_ThenNothingIsSelected',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(harness.read(songSelectionProvider).isActive, isFalse);
      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets(
    'GivenASelectionInSongs_WhenAnotherDestinationIsOpened_ThenTheSelectionEnds',
    (tester) async {
      final harness = Harness(library: [a, b, c, d]);
      final shell = harness.read(shellControllerProvider.notifier)
        ..go(ShellDestination.music);
      // The shell's own choice of area, without the rest of the shell.
      await tester.pumpHarness(
        harness,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) =>
                ref.watch(shellControllerProvider) == ShellDestination.music
                ? const MusicLibraryView()
                : const SizedBox.shrink(),
          ),
        ),
      );
      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();
      await hold(tester, 'Alpha');
      expect(harness.read(songSelectionProvider).isActive, isTrue);

      shell.go(ShellDestination.queue);
      await tester.pumpAndSettle();

      expect(harness.read(songSelectionProvider).isActive, isFalse);
    },
  );

  testWidgets(
    'GivenASelection_WhenTheLibraryReloadsBehindTheSpinner_ThenTheSelectionIsKept',
    (tester) async {
      final harness = await songs(tester);
      await hold(tester, 'Alpha');

      final gate = harness.catalogs.readGate = Completer<void>();
      // As a reload, so the list gives way to the spinner rather than staying
      // on screen with the old songs while the new ones are read.
      harness.container.invalidate(
        musicLibraryControllerProvider,
        asReload: true,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
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

      // The bar's button says the same, so it is the menu's item that is
      // looked for.
      expect(find.widgetWithText(MenuItemButton, 'Edit tags…'), findsNothing);
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

  group('editing the selection’s tags', () {
    /// Songs, with a tag writer that holds all four files, and a scanner that
    /// answers a save's rescan with the same songs.
    Future<Harness> songsToEdit(WidgetTester tester) async {
      final all = [a, b, c, d];
      final harness = Harness(
        library: all,
        scanner: ScriptedScanner([
          ScanCompleted(
            catalog: MusicCatalog(entries: all),
            report: const ScanReport(
              tracks: 4,
              added: 0,
              updated: 4,
              removed: 0,
              reused: 0,
            ),
          ),
        ]),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      for (final track in all) {
        harness.tagWriter.files[track.file.path] = FileTags(
          writable: AutofillField.values.toSet(),
          values: const {AutofillField.artist: 'Band'},
        );
      }
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      return harness;
    }

    Future<void> rightClick(WidgetTester tester, String title) async {
      await tester.tap(row(title), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
    }

    Finder menuItem(String text) => find.widgetWithText(MenuItemButton, text);

    // By path: the library hands the list its own copies of the entries.
    List<String> paths(EditManyTagsDialog dialog) => [
      for (final entry in dialog.entries) entry.file.path,
    ];

    Finder barButton(String text) => find.widgetWithText(FilledButton, text);

    testWidgets(
      'GivenTwoOfFourSelected_WhenEditTagsInTheBarIsPressed_ThenTheFormOpensOverThoseTwoInListOrder',
      (tester) async {
        await songsToEdit(tester);
        await hold(tester, 'Delta');
        await tap(tester, 'Bravo');

        await tester.tap(barButton('Edit tags…'));
        await tester.pumpAndSettle();

        expect(find.byType(EditManyTagsDialog), findsOneWidget);
        expect(find.text('Selected songs · 2 songs'), findsOneWidget);
        final dialog = tester.widget<EditManyTagsDialog>(
          find.byType(EditManyTagsDialog),
        );
        expect(paths(dialog), [b.file.path, d.file.path]);
      },
    );

    testWidgets(
      'GivenOneSelected_WhenEditTagsIsPressed_ThenTheOneTrackFormOpens',
      (tester) async {
        await songsToEdit(tester);
        await hold(tester, 'Bravo');

        await tester.tap(barButton('Edit tags…'));
        await tester.pumpAndSettle();

        expect(find.byType(EditTagsDialog), findsOneWidget);
        expect(find.byType(EditManyTagsDialog), findsNothing);
      },
    );

    testWidgets(
      'GivenASelection_WhenASelectedRowIsRightClicked_ThenTheMenuOffersEditTagsOf2Songs',
      (tester) async {
        await songsToEdit(tester);
        await hold(tester, 'Alpha');
        await tap(tester, 'Charlie');

        await rightClick(tester, 'Alpha');

        expect(menuItem('Edit tags of 2 songs…'), findsOneWidget);
        expect(menuItem('Play'), findsNothing);

        await tester.tap(menuItem('Edit tags of 2 songs…'));
        await tester.pumpAndSettle();

        final dialog = tester.widget<EditManyTagsDialog>(
          find.byType(EditManyTagsDialog),
        );
        expect(paths(dialog), [a.file.path, c.file.path]);
      },
    );

    testWidgets(
      'GivenASelection_WhenAnUnselectedRowIsRightClicked_ThenItsOwnMenuOpens',
      (tester) async {
        await songsToEdit(tester);
        await hold(tester, 'Alpha');
        await tap(tester, 'Bravo');

        await rightClick(tester, 'Charlie');

        expect(menuItem('Play'), findsOneWidget);
        expect(menuItem('Edit tags…'), findsOneWidget);
        expect(menuItem('Edit tags of 2 songs…'), findsNothing);
      },
    );

    testWidgets(
      'GivenASelection_WhenARowsMoreButtonIsPressed_ThenTheSongsOwnMenuOpens',
      (tester) async {
        await songsToEdit(tester);
        await hold(tester, 'Alpha');
        await tap(tester, 'Bravo');

        // A selected row's, to show the button is not the right-click.
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: row('Alpha'),
              matching: find.byType(MusicRowMenu),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();

        expect(menuItem('Play'), findsOneWidget);
        expect(menuItem('Edit tags…'), findsOneWidget);
        expect(menuItem('Edit tags of 2 songs…'), findsNothing);
      },
    );

    testWidgets('GivenASelection_WhenTheFormSavesSongs_ThenTheSelectionEnds', (
      tester,
    ) async {
      final harness = await songsToEdit(tester);
      await hold(tester, 'Alpha');
      await tap(tester, 'Bravo');
      await tester.tap(barButton('Edit tags…'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey(AutofillField.genre)),
        'Rock',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.tagWriter.writes, hasLength(2));
      expect(find.byType(EditManyTagsDialog), findsNothing);
      expect(selected(harness), isEmpty);
      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('GivenASelection_WhenTheFormIsCancelled_ThenTheSelectionStays', (
      tester,
    ) async {
      final harness = await songsToEdit(tester);
      await hold(tester, 'Alpha');
      await tap(tester, 'Bravo');
      await tester.tap(barButton('Edit tags…'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(EditManyTagsDialog), findsNothing);
      expect(selected(harness), {a.file.path, b.file.path});
      expect(find.text('2 selected'), findsOneWidget);
    });
  });
}
