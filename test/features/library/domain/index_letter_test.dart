import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/index_letter.dart';

/// The letter a name is filed under, and where each letter starts in a list.
void main() {
  group('indexLetterOf', () {
    test('GivenANameStartingWithALowerCaseLetter_WhenItIsFiled_ThenItIsUnderTheCapital', () {
      expect(indexLetterOf('radiohead'), 'R');
    });

    test('GivenANameStartingWithAnAccentedLetter_WhenItIsFiled_ThenItIsUnderThePlainLetter', () {
      expect(indexLetterOf('Édith Piaf'), 'E');
      expect(indexLetterOf('Ângela Rô Rô'), 'A');
      expect(indexLetterOf('Çava'), 'C');
      expect(indexLetterOf('Ñu'), 'N');
    });

    test(
      'GivenANameStartingWithADigitOrSymbol_WhenItIsFiled_ThenItIsUnderTheHash',
      () {
        expect(indexLetterOf('1999'), indexOther);
        expect(indexLetterOf('...And Justice'), indexOther);
        expect(indexLetterOf('ガゼット'), indexOther);
      },
    );

    test(
      'GivenANameWithLeadingSpaces_WhenItIsFiled_ThenTheSpacesAreSkipped',
      () {
        expect(indexLetterOf('  Muse'), 'M');
      },
    );

    test('GivenNoName_WhenItIsFiled_ThenItIsUnderNoLetter', () {
      expect(indexLetterOf(null), isNull);
      expect(indexLetterOf('   '), isNull);
    });
  });

  group('firstIndexByLetter', () {
    test('GivenNamesInListOrder_WhenTheyAreIndexed_ThenEachLetterPointsAtItsFirstName', () {
      final starts = firstIndexByLetter([
        '1999',
        'Abba',
        'Air',
        'Muse',
        'Mogwai',
        null,
      ]);

      expect(starts, {indexOther: 0, 'A': 1, 'M': 3});
    });

    test('GivenALetterThatReturnsLaterInTheList_WhenTheyAreIndexed_ThenItsFirstAppearanceWins', () {
      // An accented name sorts after Z, but the letter still leads to the
      // block of names the owner sees at E.
      final starts = firstIndexByLetter(['Eagles', 'Zappa', 'Édith Piaf']);

      expect(starts['E'], 0);
    });
  });

  test('GivenTheIndex_WhenItsLettersAreRead_ThenTheHashLeadsAndAToZFollow', () {
    expect(indexLetters.first, indexOther);
    expect(indexLetters.skip(1).join(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
  });
}
