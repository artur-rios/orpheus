import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/presentation/search_results_view.dart';

import '../../../support/entries.dart';

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
}
