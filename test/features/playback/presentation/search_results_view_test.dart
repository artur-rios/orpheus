import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/presentation/search_results_view.dart';
import 'package:orpheus/features/shell/application/shell_controller.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Matching what the owner typed against the library.
void main() {
  final library = [
    entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: '2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: '3', title: 'Air', artist: 'Talvin Singh', album: 'OK'),
    entry(id: '4'),
  ];

  test(
    'GivenATermThatStartsATitle_WhenTheLibraryIsSearched_ThenThatTrackComesFirst',
    () {
      // A term is usually the start of a title, so a match at the beginning of
      // a field is what the owner meant.
      final results = matchesIn(library, 'air');

      expect(results.first.title, 'Air');
      expect([for (final e in results) e.title], contains('Airbag'));
    },
  );

  test(
    'GivenATermMatchingAnArtist_WhenTheLibraryIsSearched_ThenEveryTrackByThemComesBack',
    () {
      expect(matchesIn(library, 'radiohead').length, 2);
    },
  );

  test(
    'GivenATermInADifferentCase_WhenTheLibraryIsSearched_ThenItStillMatches',
    () {
      expect(matchesIn(library, 'KARMA').single.title, 'Karma Police');
    },
  );

  test(
    'GivenATermMatchingNothing_WhenTheLibraryIsSearched_ThenNothingComesBack',
    () {
      expect(matchesIn(library, 'zzzz'), isEmpty);
    },
  );

  test(
    'GivenAnEmptyTerm_WhenTheLibraryIsSearched_ThenNothingComesBackRatherThanEverything',
    () {
      expect(matchesIn(library, '   '), isEmpty);
    },
  );

  test(
    'GivenAFileWithNoTagsAtAll_WhenTheLibraryIsSearched_ThenItIsNeverMatchedByItsNameOnDisk',
    () {
      // The fixture names every file `zzz-<id>.flac`, so a search that fell
      // back to the name on disk would find it here.
      expect(matchesIn(library, 'zzz'), isEmpty);
    },
  );

  test(
    'GivenATermMatchingAnAlbum_WhenTheLibraryIsSearched_ThenItsTracksComeBackBelowTitleMatches',
    () {
      final results = matchesIn(library, 'ok computer');

      expect(results.length, 2);
    },
  );

  test(
    'GivenTheSameSearchRunTwice_WhenTheResultsAreCompared_ThenTheyAreInTheSameOrder',
    () {
      // Results that reordered between one keystroke and the next would be a
      // list nobody could click.
      expect(
        [for (final e in matchesIn(library, 'a')) e.file.path],
        [for (final e in matchesIn(library, 'a')) e.file.path],
      );
    },
  );

  group('narrowed to one kind of tag', () {
    final taggedRock = entry(id: '5', title: 'Plain', genres: ['Rock']);

    test(
      'GivenATrackTaggedRock_WhenRockIsSearchedUnderSongs_ThenItIsNotAMatch',
      () {
        expect(
          matchesIn([taggedRock], 'rock', field: SearchField.songs),
          isEmpty,
        );
      },
    );

    test(
      'GivenATrackTaggedRock_WhenRockIsSearchedUnderGenres_ThenItMatches',
      () {
        expect(
          matchesIn([taggedRock], 'rock', field: SearchField.genres),
          [taggedRock],
        );
      },
    );

    test(
      'GivenATrackWithSeveralGenres_WhenAnyOfThemIsSearchedUnderGenres_ThenItMatches',
      () {
        final multi = entry(id: '6', genres: ['Rock', 'Trip-Hop']);

        expect(matchesIn([multi], 'trip', field: SearchField.genres), [multi]);
      },
    );

    test(
      'GivenATitleMatchAndAGenreMatch_WhenSearchedUnderAll_ThenTheTitleMatchComesFirst',
      () {
        final byGenre = entry(id: '7', title: 'Alpha', genres: ['Rock']);
        final byTitle = entry(id: '8', title: 'Rock Me', genres: ['Pop']);

        final results = matchesIn([byGenre, byTitle], 'rock');

        expect(results, [byTitle, byGenre]);
      },
    );

    test(
      'GivenAGenreMatchAndAnAlbumMatch_WhenSearchedUnderAll_ThenTheAlbumMatchComesFirst',
      () {
        final byGenre = entry(id: '9', title: 'Alpha', genres: ['Rock']);
        final byAlbum = entry(id: '10', title: 'Beta', album: 'Rock Opera');

        expect(matchesIn([byGenre, byAlbum], 'rock'), [byAlbum, byGenre]);
      },
    );

    test(
      'GivenAnAlbumArtistOnly_WhenSearchedUnderArtists_ThenItMatches',
      () {
        final compilation = entry(
          id: '11',
          title: 'Track',
          artist: 'Someone',
          albumArtist: 'Various Artists',
        );

        expect(
          matchesIn([compilation], 'various', field: SearchField.artists),
          [compilation],
        );
      },
    );

    test(
      'GivenATitle_WhenItIsSearchedUnderArtistsAndUnderAlbums_ThenItIsNotAMatch',
      () {
        final track = entry(id: '12', title: 'Karma', artist: 'Radiohead');

        expect(
          matchesIn([track], 'karma', field: SearchField.artists),
          isEmpty,
        );
        expect(
          matchesIn([track], 'karma', field: SearchField.albums),
          isEmpty,
        );
      },
    );

    test('GivenAnAlbum_WhenSearchedUnderAlbums_ThenItMatches', () {
      final track = entry(id: '13', album: 'OK Computer');

      expect(
        matchesIn([track], 'computer', field: SearchField.albums),
        [track],
      );
    });
  });

  group('the selector', () {
    final rocker = entry(id: '1', title: 'Hammer', genres: ['Rock']);
    final titled = entry(id: '2', title: 'Rock Steady', genres: ['Soul']);

    Future<Harness> show(
      WidgetTester tester, {
      required String term,
      Size window = desktopWindow,
      Locale locale = const Locale('en'),
    }) async {
      final harness = Harness(library: [rocker, titled]);
      harness.read(searchTermProvider.notifier).type(term);
      await tester.pumpHarness(
        harness,
        const Scaffold(body: SearchResultsView()),
        window: window,
        locale: locale,
      );
      return harness;
    }

    testWidgets(
      'GivenASearch_WhenGenresIsChosen_ThenOnlyGenreMatchesAreListed',
      (tester) async {
        await show(tester, term: 'rock');
        expect(find.text('Hammer'), findsOneWidget);
        expect(find.text('Rock Steady'), findsOneWidget);

        await tester.tap(find.text('Genres'));
        await tester.pumpAndSettle();

        expect(find.text('Hammer'), findsOneWidget);
        expect(find.text('Rock Steady'), findsNothing);
      },
    );

    testWidgets(
      'GivenGenresChosen_WhenTheSearchIsClearedAndTypedAgain_ThenGenresIsStillChosen',
      (tester) async {
        final harness = await show(tester, term: 'rock');

        await tester.tap(find.text('Genres'));
        await tester.pumpAndSettle();
        harness.read(searchTermProvider.notifier).clear();
        harness.read(searchTermProvider.notifier).type('rock');
        await tester.pumpAndSettle();

        expect(harness.read(searchFieldProvider), SearchField.genres);
        expect(find.text('Rock Steady'), findsNothing);
      },
    );

    testWidgets(
      'GivenANewHarness_WhenNothingHasBeenChosen_ThenAllIsTheField',
      (tester) async {
        final harness = await show(tester, term: 'rock');

        expect(harness.read(searchFieldProvider), SearchField.all);
      },
    );

    testWidgets(
      'GivenANarrowedSearchWithNoResults_WhenShown_ThenTheSelectorIsStillThere',
      (tester) async {
        final harness = await show(tester, term: 'steady');

        await tester.tap(find.text('Genres'));
        await tester.pumpAndSettle();

        expect(find.text('Rock Steady'), findsNothing);
        expect(find.textContaining('Nothing in the library'), findsOneWidget);
        expect(find.byType(SegmentedButton<SearchField>), findsOneWidget);
        expect(harness.read(searchFieldProvider), SearchField.genres);
      },
    );

    testWidgets(
      'GivenAPhoneInPortuguese_WhenResultsAreShown_ThenTheSelectorScrollsRatherThanOverflows',
      (tester) async {
        await show(
          tester,
          term: 'rock',
          window: phoneWindow,
          locale: const Locale('pt'),
        );

        expect(tester.takeException(), isNull);
        for (final label in ['Tudo', 'Faixas', 'Artistas', 'Álbuns']) {
          expect(find.text(label), findsOneWidget);
        }

        await tester.ensureVisible(find.text('Gêneros'));
        await tester.pumpAndSettle();

        expect(find.text('Gêneros'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
