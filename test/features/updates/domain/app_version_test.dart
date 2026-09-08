import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';

/// Which of two releases is later.
///
/// The whole update check rests on this: a comparison that is wrong by one
/// either offers an owner a version they already have, or never tells them
/// about the one they do not.
void main() {
  AppVersion parse(String text) => AppVersion.tryParse(text)!;

  test(
    'GivenTagsAsTheWorkflowWritesThem_WhenTheyAreParsed_ThenTheLeadingVIsNotPartOfTheVersion',
    () {
      expect(parse('v1.0.1').toString(), '1.0.1');
      expect(parse('1.0.1').toString(), '1.0.1');
    },
  );

  test(
    'GivenAVersionCarryingABuildNumber_WhenItIsParsed_ThenTheBuildIsDropped',
    () {
      // `1.0.1+2` and `1.0.1+7` are the same release. The number after the
      // plus is what Android reads as its versionCode and says nothing about
      // precedence — treating it as part of the version would offer an update
      // to a package identical to the one running.
      expect(parse('1.0.1+2'), parse('1.0.1+7'));
      expect(parse('1.0.1+2').isAfter(parse('1.0.1')), isFalse);
    },
  );

  test(
    'GivenTenAndNine_WhenTheyAreCompared_ThenTheyCompareAsNumbersNotAsText',
    () {
      // The comparison a string sort gets wrong, and the one a version scheme
      // meets on its tenth release.
      expect(parse('1.10.0').isAfter(parse('1.9.0')), isTrue);
      expect(parse('1.0.10').isAfter(parse('1.0.9')), isTrue);
      expect(parse('2.0.0').isAfter(parse('1.99.99')), isTrue);
    },
  );

  test(
    'GivenAPreRelease_WhenComparedWithTheVersionItLeadsTo_ThenItIsEarlier',
    () {
      // What stops somebody running 1.1.0 being offered 1.1.0-beta.1 as an
      // upgrade to it.
      expect(parse('1.1.0-beta.1').isAfter(parse('1.1.0')), isFalse);
      expect(parse('1.1.0').isAfter(parse('1.1.0-beta.1')), isTrue);
      expect(parse('1.1.0-beta.1').isAfter(parse('1.0.9')), isTrue);
    },
  );

  test(
    'GivenTwoPreReleases_WhenTheyAreCompared_ThenTheirNumbersCompareAsNumbers',
    () {
      expect(parse('1.1.0-beta.10').isAfter(parse('1.1.0-beta.9')), isTrue);
      expect(parse('1.1.0-beta.2').isAfter(parse('1.1.0-alpha.9')), isTrue);
      expect(parse('1.1.0-beta.1.2').isAfter(parse('1.1.0-beta.1')), isTrue);
    },
  );

  test(
    'GivenSomethingThatIsNotAVersion_WhenItIsParsed_ThenNothingComesBack',
    () {
      // The release check compares against this. Something it cannot read is
      // a reason to leave the owner alone, not to guess.
      for (final text in ['', 'v', 'latest', '1.0', '1.0.0.0', 'v1.x.0', 'v-1.0.0']) {
        expect(AppVersion.tryParse(text), isNull, reason: 'parsed "$text"');
      }
    },
  );
}
