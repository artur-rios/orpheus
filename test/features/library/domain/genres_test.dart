import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/genres.dart';

/// Splitting a genre tag into genres, and matching them so the same genre
/// spelled three ways is one genre.
void main() {
  test(
    'GivenOneValueWithSemicolons_WhenSplit_ThenEachGenreComesBackTrimmed',
    () {
      expect(splitGenres(['Rock; Pop ;Jazz']), ['Rock', 'Pop', 'Jazz']);
    },
  );

  test('GivenPipesAndCommas_WhenSplit_ThenTheyAreSeparatorsToo', () {
    expect(splitGenres(['Rock|Pop', 'Jazz, Soul']), [
      'Rock',
      'Pop',
      'Jazz',
      'Soul',
    ]);
  });

  test('GivenASlash_WhenSplit_ThenItStaysPartOfTheName', () {
    expect(splitGenres(['Hip-Hop/Rap', 'R&B/Soul']), [
      'Hip-Hop/Rap',
      'R&B/Soul',
    ]);
  });

  test('GivenEmptyPartsAndBlankValues_WhenSplit_ThenNothingBlankComesBack', () {
    expect(splitGenres(['Rock;', '; Pop', 'Rock;;Pop', ',', '   ', null]), [
      'Rock',
      'Pop',
    ]);
  });

  test('GivenTheSameGenreSpelledThreeWays_WhenSplit_ThenItComesBackOnceAsFirstSpelled', () {
    expect(splitGenres(['Rock; rock; ROCK ']), ['Rock']);
  });

  test('GivenNoValues_WhenSplit_ThenThereAreNoGenres', () {
    expect(splitGenres(const []), isEmpty);
  });

  test('GivenSpacingAndCase_WhenKeyed_ThenTheKeysAgree', () {
    expect(genreKey(' Rock '), genreKey('rock'));
  });
}
