import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/presentation/genres_view.dart';
import 'package:orpheus/features/playback/presentation/music_rows.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Genres: the list of them, what playing one queues, and browsing inside one.
void main() {
  // OK Computer is a mixed record: one Rock track, one Alternative. Radiohead
  // also has Kid A, which is not Rock at all, and the demo carries no genre.
  final library = [
    entry(
      id: '1',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      genres: const ['Rock'],
      track: 1,
      duration: const Duration(minutes: 4, seconds: 44),
    ),
    entry(
      id: '2',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      genres: const ['Alternative'],
      track: 2,
    ),
    entry(
      id: '3',
      title: 'Everything',
      artist: 'Radiohead',
      album: 'Kid A',
      genres: const ['Electronic'],
      track: 1,
    ),
    entry(
      id: '4',
      title: 'So What',
      artist: 'Miles Davis',
      album: 'Kind of Blue',
      genres: const ['Jazz'],
      track: 1,
    ),
    entry(
      id: '5',
      title: 'War Pigs',
      artist: 'Black Sabbath',
      album: 'Paranoid',
      genres: const ['Rock'],
      track: 1,
      duration: const Duration(minutes: 7, seconds: 56),
    ),
    entry(id: '6', title: 'Demo', artist: 'Nobody', album: 'Tapes'),
  ];

  Widget area() => const Scaffold(body: GenresView());

  Finder rowOf(String genre) => find.widgetWithText(ListTile, genre);

  Future<Harness> openRock(WidgetTester tester) async {
    final harness = Harness(library: library);
    await tester.pumpHarness(harness, area());
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();

    return harness;
  }

  testWidgets(
    'GivenALibraryWithGenres_WhenGenresIsOpened_ThenEachIsListedWithNoGenreLast',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, area());

      final names = ['Alternative', 'Electronic', 'Jazz', 'Rock', 'No genre'];
      final tops = [
        for (final name in names) tester.getTopLeft(rowOf(name)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      // A total where every length is known, and the count alone where one is
      // not: a sum that skipped the unmeasured tracks would mislead.
      expect(find.text('2 tracks · 12:40'), findsOneWidget);
      expect(
        find.descendant(of: rowOf('Jazz'), matching: find.text('1 track')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenAGenreRow_WhenPlayIsPressed_ThenOnlyItsTaggedTracksAreQueuedUnderItsName',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(
        find.descendant(
          of: rowOf('Rock'),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pumpAndSettle();

      final queue = harness.read(audioPlaybackControllerProvider).queue;
      expect(queue.label, 'Rock');
      // Karma Police shares Airbag's record but is not Rock; by artist, so
      // Black Sabbath before Radiohead.
      expect(queue.tracks, [file('5'), file('1')]);
    },
  );

  testWidgets(
    'GivenAGenreRow_WhenTapped_ThenItsArtistsAreShownUnderAGenresCrumb',
    (tester) async {
      final harness = await openRock(tester);

      expect(harness.read(genreBrowseControllerProvider).inGenre, isTrue);
      expect(find.text('Radiohead'), findsOneWidget);
      expect(find.text('Black Sabbath'), findsOneWidget);
      expect(find.text('Miles Davis'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Genres'), findsOneWidget);
      // The Music tab's place is its own.
      expect(harness.read(musicBrowseControllerProvider).inArtist, isFalse);
    },
  );

  testWidgets(
    'GivenAMixedRecordUnderRock_WhenOpened_ThenAllItsTracksAreShown',
    (tester) async {
      await openRock(tester);
      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK Computer'));
      await tester.pumpAndSettle();

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('Karma Police'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnArtistInsideRock_WhenPlayIsPressed_ThenOnlyTheirRockRecordsAreQueued',
    (tester) async {
      final harness = await openRock(tester);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Radiohead'),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pumpAndSettle();

      // OK Computer whole, as it is browsed; Kid A is not under Rock.
      expect(harness.read(audioPlaybackControllerProvider).queue.tracks, [
        file('1'),
        file('2'),
      ]);
    },
  );

  testWidgets('GivenRocksSongs_WhenShown_ThenOnlyTracksTaggedRockAreListed', (
    tester,
  ) async {
    await openRock(tester);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    expect(find.text('Airbag'), findsOneWidget);
    expect(find.text('War Pigs'), findsOneWidget);
    expect(find.text('Karma Police'), findsNothing);
  });

  testWidgets('GivenTheGenresCrumb_WhenTapped_ThenTheListIsShownAgain', (
    tester,
  ) async {
    final harness = await openRock(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Genres'));
    await tester.pumpAndSettle();

    expect(harness.read(genreBrowseControllerProvider).inGenre, isFalse);
    expect(rowOf('Jazz'), findsOneWidget);
    expect(rowOf('No genre'), findsOneWidget);
  });

  testWidgets(
    'GivenRockIsOpen_WhenTheToolbarShuffleIsPressed_ThenOnlyItsTaggedTracksAreQueuedUnderItsName',
    (tester) async {
      // Not the whole library, which is what the same button shuffles under
      // Music, and not OK Computer whole, which is how the record is browsed:
      // Karma Police is on a Rock record but is not Rock.
      final harness = await openRock(tester);

      await tester.tap(find.byTooltip('Shuffle the genre'));
      await tester.pumpAndSettle();

      final queue = harness.read(audioPlaybackControllerProvider).queue;
      expect(queue.label, 'Rock');
      expect(queue.tracks, unorderedEquals([file('1'), file('5')]));
    },
  );

  testWidgets(
    'GivenTheNoGenreRow_WhenTapped_ThenItsArtistsAreShownUnderANoGenreCrumb',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(find.text('No genre'));
      await tester.pumpAndSettle();

      final state = harness.read(genreBrowseControllerProvider);
      expect(state.inGenre, isTrue);
      expect(state.genre, isNull);
      expect(find.text('Nobody'), findsOneWidget);
      expect(find.text('Radiohead'), findsNothing);
      // The list's row is gone, so this is the crumb naming where the owner is.
      expect(rowOf('No genre'), findsNothing);
      expect(find.text('No genre'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Genres'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnEmptyLibrary_WhenGenresIsOpened_ThenTheLibrarysEmptyMessageIsShown',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, area());

      expect(find.text('Your library is empty.'), findsOneWidget);
      expect(find.text('Add a folder'), findsOneWidget);
    },
  );

  group('Edit tags inside a genre', () {
    // OK Computer has two Rock tracks and one that is not; Radiohead's loose
    // tracks are two Rock and one Jazz; Kid A is not Rock at all.
    final tagged = [
      entry(
        id: 'r1',
        title: 'Airbag',
        artist: 'Radiohead',
        album: 'OK Computer',
        genres: const ['Rock'],
        track: 1,
      ),
      entry(
        id: 'r2',
        title: 'Karma Police',
        artist: 'Radiohead',
        album: 'OK Computer',
        genres: const ['Alternative'],
        track: 2,
      ),
      entry(
        id: 'r3',
        title: 'Lucky',
        artist: 'Radiohead',
        album: 'OK Computer',
        genres: const ['Rock'],
        track: 3,
      ),
      entry(
        id: 'l1',
        title: 'Demo One',
        artist: 'Radiohead',
        genres: const ['Rock'],
      ),
      entry(
        id: 'l2',
        title: 'Demo Two',
        artist: 'Radiohead',
        genres: const ['Rock'],
      ),
      entry(
        id: 'l3',
        title: 'Demo Three',
        artist: 'Radiohead',
        genres: const ['Jazz'],
      ),
      entry(
        id: 'k1',
        title: 'Everything',
        artist: 'Radiohead',
        album: 'Kid A',
        genres: const ['Electronic'],
        track: 1,
      ),
    ];

    Future<void> openRockIn(WidgetTester tester, {required bool albums}) async {
      await tester.pumpHarness(Harness(library: tagged), area());
      await tester.tap(find.text('Rock'));
      await tester.pumpAndSettle();
      if (albums) {
        await tester.tap(find.text('Albums'));
        await tester.pumpAndSettle();
      }
    }

    Future<void> editTagsOf(WidgetTester tester, String row) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text(row),
            matching: find.byType(MusicGroupMenu),
          ),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit tags…'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'GivenANamedAlbumShownInsideAGenre_WhenEditTagsIsPicked_ThenTheFormOpensOverTheWholeAlbum',
      (tester) async {
        await openRockIn(tester, albums: true);

        await editTagsOf(tester, 'OK Computer');

        // Karma Police is not Rock, and is on the record all the same.
        expect(find.byType(EditManyTagsDialog), findsOneWidget);
        expect(find.text('OK Computer · 3 songs'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnUntitledAlbumShownInsideAGenre_WhenEditTagsIsPicked_ThenTheFormOpensOverTheGenresTracksOnly',
      (tester) async {
        await openRockIn(tester, albums: true);

        await editTagsOf(tester, 'Unknown album');

        // A nameless group is not a record: Demo Three is Jazz, and not in it.
        expect(find.byType(EditManyTagsDialog), findsOneWidget);
        expect(find.text('Unknown album · 2 songs'), findsOneWidget);
      },
    );

    testWidgets(
      'GivenAnArtistShownInsideAGenre_WhenEditTagsIsPicked_ThenTheFormOpensOverAllTheirTracks',
      (tester) async {
        await openRockIn(tester, albums: false);
        // Under Rock the row holds OK Computer whole and the two Rock demos.
        expect(find.text('5 tracks'), findsOneWidget);

        await editTagsOf(tester, 'Radiohead');

        expect(find.byType(EditManyTagsDialog), findsOneWidget);
        expect(find.text('Radiohead · 7 songs'), findsOneWidget);
      },
    );
  });

  /// Answers the fields dialog a started autofill opens with its defaults.
  Future<void> confirmFields(WidgetTester tester) async {
    expect(find.text('Fill which tags?'), findsOneWidget);
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
  }

  testWidgets('GivenAGenreRow_WhenRightClicked_ThenAutofillTagsIsOffered', (
    tester,
  ) async {
    final harness = Harness(library: library);
    await tester.pumpHarness(harness, area());

    await tester.tap(rowOf('Rock'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Autofill tags…'), findsOneWidget);
    // Opened by the menu, not by the tap a row otherwise answers.
    expect(harness.read(genreBrowseControllerProvider).inGenre, isFalse);
  });

  testWidgets('GivenAGenreRow_WhenTouchedAndHeld_ThenAutofillTagsIsOffered', (
    tester,
  ) async {
    final harness = Harness(library: library);
    await tester.pumpHarness(harness, area());

    await tester.longPress(rowOf('Rock'));
    await tester.pumpAndSettle();

    expect(find.text('Autofill tags…'), findsOneWidget);
  });

  testWidgets(
    'GivenAGenreRow_WhenItsMoreButtonIsPressedAndAutofillTapped_ThenOnlyItsTaggedSongsAreCounted',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(
        find.descendant(
          of: rowOf('Rock'),
          matching: find.byTooltip('More actions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autofill tags…'));
      await tester.pumpAndSettle();
      await confirmFields(tester);

      // Airbag and War Pigs; Karma Police shares a record but is not Rock.
      expect(find.text('Autofill 2 songs?'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAGenreRow_WhenPlayAndShuffleAreLookedFor_ThenTheyStillSitBesideTheMenuButton',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      for (final tooltip in [
        'Play the genre',
        'Shuffle the genre',
        'More actions',
      ]) {
        expect(
          find.descendant(of: rowOf('Rock'), matching: find.byTooltip(tooltip)),
          findsOneWidget,
          reason: tooltip,
        );
      }
    },
  );

  testWidgets(
    'GivenAnOpenGenre_WhenControlsMenuAutofillTapped_ThenOnlyItsSongsAreCounted',
    (tester) async {
      await openRock(tester);

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.byTooltip('Shuffle the genre'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autofill tags…'));
      await tester.pumpAndSettle();
      await confirmFields(tester);

      // What its shuffle plays: two Rock tracks, not the library's six.
      expect(find.text('Autofill 2 songs?'), findsOneWidget);
    },
  );
}
