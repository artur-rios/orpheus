import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/presentation/genres_view.dart';

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
}
