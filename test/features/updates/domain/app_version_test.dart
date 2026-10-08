import 'dart:io';

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
    'GivenTheSemVerSpecificationsOwnExample_WhenSorted_ThenTheyFallInItsOrder',
    () {
      // Section 11 of SemVer 2.0.0, verbatim. Every rule of pre-release
      // precedence is in this one chain.
      const ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
      ];

      final shuffled = [for (final text in ordered.reversed) parse(text)]
        ..sort();

      expect([for (final version in shuffled) '$version'], ordered);
    },
  );

  test(
    'GivenTheBetasOfARelease_WhenComparedWithItAndEachOther_ThenEachIsOfferedTheNext',
    () {
      // The path a beta tester takes: every later beta, then the release.
      expect(parse('v1.3.0-beta.2').isAfter(parse('1.3.0-beta.1')), isTrue);
      expect(parse('v1.3.0').isAfter(parse('1.3.0-beta.2')), isTrue);
      expect(parse('v1.3.0-beta.1').isAfter(parse('1.3.0-beta.2')), isFalse);
      expect(parse('1.3.0-beta.1+7'), parse('v1.3.0-beta.1'));
      expect(parse('1.3.0-beta.1+7').isPreRelease, isTrue);
    },
  );

  test(
    'GivenIdentifiersThatOnlyLookNumeric_WhenTheyAreCompared_ThenTheyCompareAsText',
    () {
      // SemVer's numeric identifier is digits only. `0x1` and `-1` are
      // alphanumeric, and an alphanumeric identifier outranks a numeric one.
      expect(parse('1.0.0-0x1').isAfter(parse('1.0.0-2')), isTrue);
      expect(parse('1.0.0-beta.-1').isAfter(parse('1.0.0-beta.5')), isTrue);
    },
  );

  test(
    'GivenPreReleaseNumbersTooLargeForAnInteger_WhenTheyAreCompared_ThenTheyStillCompareAsNumbers',
    () {
      expect(
        parse('1.0.0-beta.100000000000000000000')
            .isAfter(parse('1.0.0-beta.99999999999999999999')),
        isTrue,
      );
      // A major, minor or patch that large is beyond anything this
      // application will be numbered, and is refused rather than misread.
      expect(AppVersion.tryParse('100000000000000000000.0.0'), isNull);
    },
  );

  test(
    'GivenThisRepositorysOwnPubspec_WhenItsVersionIsParsed_ThenTheUpdateCheckCanReadIt',
    () {
      // The running build reports what `version:` says, pre-release included.
      // A version this cannot parse is a build that silently never checks.
      final pubspec = File('pubspec.yaml').readAsLinesSync();
      final line = pubspec.firstWhere((line) => line.startsWith('version:'));

      expect(AppVersion.tryParse(line.substring('version:'.length)), isNotNull);
    },
  );

  test(
    'GivenSomethingThatIsNotAVersion_WhenItIsParsed_ThenNothingComesBack',
    () {
      // The release check compares against this. Something it cannot read is
      // a reason to leave the owner alone, not to guess.
      for (final text in [
        '',
        'v',
        'latest',
        '1.0',
        '1.0.0.0',
        'v1.x.0',
        'v-1.0.0',
        // Not SemVer 2.0.0: leading zeros, empty identifiers, characters
        // outside [0-9A-Za-z-].
        '01.0.0',
        '1.02.0',
        '1.0.0-01',
        '1.0.0-',
        '1.0.0-beta..1',
        '1.0.0-beta.',
        '1.0.0+',
        '1.0.0-beta_1',
        '1.0.0-beta.1+build..2',
      ]) {
        expect(AppVersion.tryParse(text), isNull, reason: 'parsed "$text"');
      }
    },
  );
}
