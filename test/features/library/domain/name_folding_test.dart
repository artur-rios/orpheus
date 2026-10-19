import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/name_folding.dart';

/// Reading a name without its accents.
void main() {
  test(
    'GivenAnUpperCaseAccentedLetter_WhenItIsFolded_ThenItIsThePlainCapital',
    () {
      expect(foldAccents('Ângela'), 'Angela');
    },
  );

  test(
    'GivenALowerCaseAccentedLetter_WhenItIsFolded_ThenItIsThePlainSmallLetter',
    () {
      expect(foldAccents('ação'), 'acao');
    },
  );

  test(
    'GivenAccentsThroughoutAName_WhenItIsFolded_ThenEveryOneIsDropped',
    () {
      expect(foldAccents('Björk Guðmundsdóttir'), 'Bjork Guðmundsdottir');
    },
  );

  test(
    'GivenAPlainName_WhenItIsFolded_ThenItIsUnchanged',
    () {
      expect(foldAccents('Radiohead 1999'), 'Radiohead 1999');
    },
  );

  test(
    'GivenALetterOutsideTheLatinAlphabet_WhenItIsFolded_ThenItIsLeftAsItIs',
    () {
      expect(foldAccents('ガゼット'), 'ガゼット');
    },
  );
}
