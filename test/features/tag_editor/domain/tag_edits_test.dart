import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/tag_editor/domain/tag_edits.dart';

/// What a form changed, and what it may not change.
void main() {
  final png = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    1,
  ]);
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 2]);

  final before = FileTags(
    writable: AutofillField.values.toSet(),
    values: const {
      AutofillField.title: 'Airbag',
      AutofillField.artist: 'Radiohed',
      AutofillField.trackNumber: 3,
      AutofillField.discNumber: '1; 2',
      AutofillField.genre: 'Rock; Pop',
    },
    cover: png,
  );

  /// The form as it opens: every field showing what the file holds.
  Map<AutofillField, String> opened(FileTags tags) => {
    for (final field in editableTextFields) field: shownText(tags, field),
  };

  TagForm formWith(
    Map<AutofillField, String> changes, {
    CoverChoice cover = const KeepCover(),
  }) => TagForm(text: {...opened(before), ...changes}, cover: cover);

  group('tagEdits', () {
    test('GivenTheFormAsItOpened_WhenCompared_ThenNothingChanged', () {
      expect(tagEdits(before, formWith(const {})), isEmpty);
    });

    test(
      'GivenATitleRetyped_WhenCompared_ThenOnlyTheTitleIsWrittenTrimmed',
      () {
        expect(
          tagEdits(before, formWith({AutofillField.title: '  Airbag (Live) '})),
          {AutofillField.title: 'Airbag (Live)'},
        );
      },
    );

    test('GivenAFieldOnlyPaddedWithSpaces_WhenCompared_ThenItIsNoChange', () {
      expect(
        tagEdits(before, formWith({AutofillField.title: ' Airbag  '})),
        isEmpty,
      );
    });

    test('GivenAFieldCleared_WhenCompared_ThenItsTagIsRemoved', () {
      expect(tagEdits(before, formWith({AutofillField.artist: '   '})), {
        AutofillField.artist: null,
      });
    });

    test('GivenAnEmptyFieldLeftEmpty_WhenCompared_ThenItIsNoChange', () {
      expect(tagEdits(before, formWith({AutofillField.album: ''})), isEmpty);
    });

    test(
      'GivenAFieldHeldTwiceAndLeftAlone_WhenCompared_ThenItIsNotRewritten',
      () {
        expect(
          tagEdits(before, formWith(const {})).containsKey(AutofillField.genre),
          isFalse,
        );
        expect(
          tagEdits(
            before,
            formWith(const {}),
          ).containsKey(AutofillField.discNumber),
          isFalse,
        );
      },
    );

    test(
      'GivenAFieldHeldTwiceAndEdited_WhenCompared_ThenTheOneValueReplacesBoth',
      () {
        expect(tagEdits(before, formWith({AutofillField.genre: 'Rock'})), {
          AutofillField.genre: 'Rock',
        });
      },
    );

    test('GivenANumberTyped_WhenCompared_ThenItIsWrittenAsANumber', () {
      expect(tagEdits(before, formWith({AutofillField.trackNumber: '4'})), {
        AutofillField.trackNumber: 4,
      });
    });

    test(
      'GivenANumberRetypedWithALeadingZero_WhenCompared_ThenItIsNoChange',
      () {
        expect(
          tagEdits(before, formWith({AutofillField.trackNumber: '03'})),
          isEmpty,
        );
      },
    );

    test('GivenAnInvalidNumber_WhenCompared_ThenItIsLeftOut', () {
      expect(
        tagEdits(before, formWith({AutofillField.trackNumber: 'three'})),
        isEmpty,
      );
    });

    test('GivenAFieldTheFormatCannotHold_WhenEdited_ThenItIsNeverWritten', () {
      const tags = FileTags(
        writable: {AutofillField.title},
        values: {AutofillField.title: 'Airbag'},
      );

      expect(
        tagEdits(
          tags,
          const TagForm(
            text: {
              AutofillField.title: 'Airbag',
              AutofillField.albumArtist: 'Radiohead',
            },
          ),
        ),
        isEmpty,
      );
    });

    test('GivenTheCoverRemoved_WhenCompared_ThenTheCoverIsRemoved', () {
      expect(tagEdits(before, formWith(const {}, cover: const RemoveCover())), {
        AutofillField.cover: null,
      });
    });

    test('GivenNoCoverAndRemoveChosen_WhenCompared_ThenItIsNoChange', () {
      final bare = FileTags(writable: before.writable, values: before.values);

      expect(
        tagEdits(bare, TagForm(text: opened(bare), cover: const RemoveCover())),
        isEmpty,
      );
    });

    test('GivenANewCover_WhenCompared_ThenItsBytesAreWritten', () {
      expect(tagEdits(before, formWith(const {}, cover: ReplaceCover(jpeg))), {
        AutofillField.cover: jpeg,
      });
    });

    test('GivenTheSameCoverPickedAgain_WhenCompared_ThenItIsNoChange', () {
      expect(
        tagEdits(
          before,
          formWith(const {}, cover: ReplaceCover(Uint8List.fromList(png))),
        ),
        isEmpty,
      );
    });

    test('GivenTheCoverIsNotWritable_WhenReplaced_ThenItIsNeverWritten', () {
      const tags = FileTags(
        writable: {AutofillField.title},
        values: {AutofillField.title: 'Airbag'},
      );

      expect(
        tagEdits(tags, TagForm(text: opened(tags), cover: ReplaceCover(jpeg))),
        isEmpty,
      );
    });
  });

  group('numberProblem', () {
    for (final (text, problem) in [
      ('', null),
      ('  ', null),
      ('1', null),
      (' 12 ', null),
      ('0', NumberProblem.notAWholeNumber),
      ('-1', NumberProblem.notAWholeNumber),
      ('+3', NumberProblem.notAWholeNumber),
      ('1.5', NumberProblem.notAWholeNumber),
      ('0x10', NumberProblem.notAWholeNumber),
      ('three', NumberProblem.notAWholeNumber),
      ('99999999999999999999', NumberProblem.notAWholeNumber),
    ]) {
      test('GivenTrackNumber"$text"_WhenChecked_ThenTheProblemIs$problem', () {
        expect(numberProblem(AutofillField.trackNumber, text), problem);
      });
    }

    for (final (text, problem) in [
      ('1997', null),
      ('1', null),
      ('9999', null),
      ('0', NumberProblem.yearOutOfRange),
      ('10000', NumberProblem.yearOutOfRange),
      ('1997-08-26', NumberProblem.yearOutOfRange),
    ]) {
      test('GivenYear"$text"_WhenChecked_ThenTheProblemIs$problem', () {
        expect(numberProblem(AutofillField.year, text), problem);
      });
    }
  });

  group('numberProblems', () {
    test('GivenANumberHeldTwiceAndLeftAlone_WhenChecked_ThenItIsNoProblem', () {
      expect(numberProblems(before, formWith(const {})), isEmpty);
    });

    test('GivenAnInvalidNumberTyped_WhenChecked_ThenThatFieldIsNamed', () {
      expect(numberProblems(before, formWith({AutofillField.year: 'soon'})), {
        AutofillField.year: NumberProblem.yearOutOfRange,
      });
    });
  });

  group('isSupportedCover', () {
    test('GivenAJpegOrAPng_WhenChecked_ThenItIsSupported', () {
      expect(isSupportedCover(jpeg), isTrue);
      expect(isSupportedCover(png), isTrue);
    });

    test('GivenAGifATruncatedPngOrNothing_WhenChecked_ThenItIsNot', () {
      expect(isSupportedCover(Uint8List.fromList('GIF89a'.codeUnits)), isFalse);
      expect(isSupportedCover(Uint8List.fromList([0x89, 0x50, 0x4E])), isFalse);
      expect(isSupportedCover(Uint8List(0)), isFalse);
    });
  });

  test('GivenAnIntValue_WhenShown_ThenItIsItsDigits', () {
    expect(shownText(before, AutofillField.trackNumber), '3');
    expect(shownText(before, AutofillField.album), '');
  });
}
