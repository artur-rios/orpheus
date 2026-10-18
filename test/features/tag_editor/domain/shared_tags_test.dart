import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/tag_editor/domain/shared_tags.dart';
import 'package:orpheus/features/tag_editor/domain/tag_edits.dart';

/// What several files hold in common, and the edits a form makes to each.
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
  final samePng = Uint8List.fromList(png);
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 2]);

  FileTags file({
    Map<AutofillField, Object?> values = const {},
    Uint8List? cover,
    Set<AutofillField>? writable,
  }) => FileTags(
    writable: writable ?? AutofillField.values.toSet(),
    values: values,
    cover: cover,
  );

  /// The form as it opens: every shared field showing what the files share.
  Map<AutofillField, String> opened(SharedTags shared) => {
    for (final field in sharedTextFields) field: sharedText(shared, field),
  };

  TagForm formWith(
    SharedTags shared,
    Map<AutofillField, String> changes, {
    CoverChoice cover = const KeepCover(),
  }) => TagForm(text: {...opened(shared), ...changes}, cover: cover);

  /// The value of [field] if the files share it, failing the test if mixed.
  Object? sameValue(SharedTags shared, AutofillField field) {
    final value = shared.values[field];
    expect(value, isA<Same<Object>>());

    return (value! as Same<Object>).value;
  }

  group('SharedTags.of', () {
    test('GivenTwoFilesWithTheSameAlbum_WhenShared_ThenTheAlbumIsTheSame', () {
      final shared = SharedTags.of([
        file(values: const {AutofillField.album: 'OK Computer'}),
        file(values: const {AutofillField.album: 'OK Computer'}),
      ]);

      expect(sameValue(shared, AutofillField.album), 'OK Computer');
      expect(sharedText(shared, AutofillField.album), 'OK Computer');
      expect(isMixed(shared, AutofillField.album), isFalse);
    });

    test('GivenTwoFilesWithDifferentYears_WhenShared_ThenTheYearIsMixedAndStartsBlank', () {
      final shared = SharedTags.of([
        file(values: const {AutofillField.year: 1997}),
        file(values: const {AutofillField.year: 2000}),
      ]);

      expect(shared.values[AutofillField.year], isA<Mixed<Object>>());
      expect(sharedText(shared, AutofillField.year), '');
      expect(isMixed(shared, AutofillField.year), isTrue);
    });

    test(
      'GivenOneFileWithAGenreAndOneWithout_WhenShared_ThenTheGenreIsMixed',
      () {
        final shared = SharedTags.of([
          file(values: const {AutofillField.genre: 'Rock'}),
          file(),
        ]);

        expect(isMixed(shared, AutofillField.genre), isTrue);
        expect(sharedText(shared, AutofillField.genre), '');
      },
    );

    test('GivenNoFileWithAGenre_WhenShared_ThenTheGenreIsSameNone', () {
      final shared = SharedTags.of([file(), file()]);

      expect(isMixed(shared, AutofillField.genre), isFalse);
      expect(sameValue(shared, AutofillField.genre), isNull);
      expect(sharedText(shared, AutofillField.genre), '');
    });

    test(
      'GivenOneFileHoldingRockPop_AndOneRock_WhenShared_ThenTheGenreIsMixed',
      () {
        final shared = SharedTags.of([
          file(values: const {AutofillField.genre: 'Rock; Pop'}),
          file(values: const {AutofillField.genre: 'Rock'}),
        ]);

        expect(isMixed(shared, AutofillField.genre), isTrue);
      },
    );

    test('GivenTheSameCoverBytes_WhenShared_ThenTheCoverIsTheSame', () {
      final shared = SharedTags.of([file(cover: png), file(cover: samePng)]);

      expect(shared.cover, isA<Same<Uint8List>>());
      expect((shared.cover as Same<Uint8List>).value, png);
      expect(shared.anyCover, isTrue);
    });

    test('GivenDifferentCovers_WhenShared_ThenTheCoverIsMixed', () {
      final shared = SharedTags.of([file(cover: png), file(cover: jpeg)]);

      expect(shared.cover, isA<Mixed<Uint8List>>());
      expect(shared.anyCover, isTrue);
    });

    test('GivenOneFileWithACoverAndOneWithout_WhenShared_ThenItIsMixed', () {
      final shared = SharedTags.of([file(cover: png), file()]);

      expect(shared.cover, isA<Mixed<Uint8List>>());
      expect(shared.anyCover, isTrue);
    });

    test('GivenNoCovers_WhenShared_ThenTheCoverIsSameNone', () {
      final shared = SharedTags.of([file(), file()]);

      expect(shared.cover, isA<Same<Uint8List>>());
      expect((shared.cover as Same<Uint8List>).value, isNull);
      expect(shared.anyCover, isFalse);
    });

    test('GivenAFlacAndAFileThatCannotHoldYear_WhenShared_ThenYearIsWritableFromTheUnion', () {
      final shared = SharedTags.of([
        file(),
        file(
          writable: AutofillField.values.toSet()..remove(AutofillField.year),
        ),
      ]);

      expect(shared.writable, contains(AutofillField.year));
    });

    test(
      'GivenFilesWithDifferentWritableSets_WhenShared_ThenItIsTheirUnion',
      () {
        final shared = SharedTags.of([
          file(writable: const {AutofillField.genre}),
          file(writable: const {AutofillField.year}),
        ]);

        expect(shared.writable, {AutofillField.genre, AutofillField.year});
      },
    );
  });

  group('editsFor', () {
    test(
      'GivenAMixedYearLeftBlank_WhenEditsAreWorkedOut_ThenNoFileGetsAYear',
      () {
        final files = [
          file(values: const {AutofillField.year: 1997}),
          file(values: const {AutofillField.year: 2000}),
        ];
        final shared = SharedTags.of(files);
        final form = formWith(shared, {AutofillField.genre: 'Rock'});

        for (final f in files) {
          expect(
            editsFor(f, shared, form).values,
            isNot(contains(AutofillField.year)),
          );
        }
      },
    );

    test(
      'GivenAMixedGenreTypedAsJazz_WhenEditsAreWorkedOut_ThenEveryFileGetsJazz',
      () {
        final files = [
          file(values: const {AutofillField.genre: 'Rock'}),
          file(),
        ];
        final shared = SharedTags.of(files);
        final form = formWith(shared, {AutofillField.genre: ' Jazz '});

        for (final f in files) {
          expect(editsFor(f, shared, form).values, {
            AutofillField.genre: 'Jazz',
          });
        }
      },
    );

    test('GivenAFileThatAlreadyHoldsTheTypedGenre_WhenEditsAreWorkedOut_ThenItHasNoEdit', () {
      final holding = file(values: const {AutofillField.genre: 'Jazz'});
      final shared = SharedTags.of([holding, file()]);
      final form = formWith(shared, {AutofillField.genre: 'Jazz'});

      expect(editsFor(holding, shared, form).values, isEmpty);
    });

    test('GivenASameAlbumCleared_WhenEditsAreWorkedOut_ThenItIsRemoved', () {
      final files = [
        file(values: const {AutofillField.album: 'OK Computer'}),
        file(values: const {AutofillField.album: 'OK Computer'}),
      ];
      final shared = SharedTags.of(files);
      final form = formWith(shared, {AutofillField.album: '  '});

      expect(editsFor(files.first, shared, form).values, {
        AutofillField.album: null,
      });
    });

    test('GivenASameAlbumClearedOverAFileWithoutIt_WhenEditsAreWorkedOut_ThenNoEdit', () {
      final holding = file(values: const {AutofillField.album: 'X'});
      final shared = SharedTags.of([holding, file()]);
      // Mixed: starts blank, and blank is no change at all.
      final form = formWith(shared, {AutofillField.album: ''});

      expect(editsFor(holding, shared, form).values, isEmpty);
    });

    test('GivenATrackTotalOf03OverAFileHolding3_WhenEditsAreWorkedOut_ThenNoChange', () {
      final files = [
        file(
          values: const {
            AutofillField.trackNumber: 1,
            AutofillField.trackTotal: 3,
          },
        ),
        file(
          values: const {
            AutofillField.trackNumber: 2,
            AutofillField.trackTotal: 3,
          },
        ),
      ];
      final shared = SharedTags.of(files);
      final form = formWith(shared, {AutofillField.trackTotal: '03'});

      for (final f in files) {
        expect(editsFor(f, shared, form).values, isEmpty);
      }
    });

    test(
      'GivenATrackTotalOf12_WhenEditsAreWorkedOut_ThenItIsWrittenAsANumber',
      () {
        final f = file(values: const {AutofillField.trackNumber: 1});
        final shared = SharedTags.of([f, f]);
        final form = formWith(shared, {AutofillField.trackTotal: ' 12 '});

        expect(editsFor(f, shared, form).values, {
          AutofillField.trackTotal: 12,
        });
      },
    );

    test('GivenAFileThatCannotHoldGenre_WhenGenreIsTyped_ThenItsEditsLeaveGenreOut', () {
      final cannot = file(
        writable: AutofillField.values.toSet()..remove(AutofillField.genre),
      );
      final can = file();
      final shared = SharedTags.of([cannot, can]);
      final form = formWith(shared, {
        AutofillField.genre: 'Jazz',
        AutofillField.album: 'Kind of Blue',
      });

      expect(editsFor(cannot, shared, form).values, {
        AutofillField.album: 'Kind of Blue',
      });
      expect(editsFor(can, shared, form).values, {
        AutofillField.genre: 'Jazz',
        AutofillField.album: 'Kind of Blue',
      });
    });

    test(
      'GivenRemoveCover_WhenEditsAreWorkedOut_ThenOnlyFilesWithACoverLoseIt',
      () {
        final withCover = file(cover: png);
        final without = file();
        final shared = SharedTags.of([withCover, without]);
        final form = formWith(shared, const {}, cover: const RemoveCover());

        expect(editsFor(withCover, shared, form).values, {
          AutofillField.cover: null,
        });
        expect(editsFor(without, shared, form).values, isEmpty);
      },
    );

    test('GivenReplaceCover_WhenEditsAreWorkedOut_ThenFilesGetTheBytes', () {
      final other = file(cover: jpeg);
      final none = file();
      final shared = SharedTags.of([other, none]);
      final form = formWith(shared, const {}, cover: ReplaceCover(png));

      expect(editsFor(other, shared, form).values, {AutofillField.cover: png});
      expect(editsFor(none, shared, form).values, {AutofillField.cover: png});
    });

    test(
      'GivenReplaceCover_WhenAFileAlreadyHoldsThoseBytes_ThenItHasNoCoverEdit',
      () {
        final holding = file(cover: samePng);
        final other = file(cover: jpeg);
        final shared = SharedTags.of([holding, other]);
        final form = formWith(shared, const {}, cover: ReplaceCover(png));

        expect(editsFor(holding, shared, form).values, isEmpty);
        expect(editsFor(other, shared, form).values, {
          AutofillField.cover: png,
        });
      },
    );

    test(
      'GivenAFileThatCannotHoldACover_WhenReplaceCover_ThenItHasNoCoverEdit',
      () {
        final cannot = file(
          writable: AutofillField.values.toSet()..remove(AutofillField.cover),
        );
        final shared = SharedTags.of([cannot, file()]);
        final form = formWith(shared, const {}, cover: ReplaceCover(png));

        expect(editsFor(cannot, shared, form).values, isEmpty);
      },
    );

    test('GivenATrackTotalForAFileWithNoTrackNumber_WhenEditsAreWorkedOut_ThenTheTotalIsLeftAndNoted', () {
      final numbered = file(values: const {AutofillField.trackNumber: 1});
      final unnumbered = file();
      final shared = SharedTags.of([numbered, unnumbered]);
      final form = formWith(shared, {
        AutofillField.trackTotal: '12',
        AutofillField.genre: 'Jazz',
      });

      final edits = editsFor(unnumbered, shared, form);
      expect(edits.values, {AutofillField.genre: 'Jazz'});
      expect(edits.leftForMissingNumber, {AutofillField.trackTotal});

      final other = editsFor(numbered, shared, form);
      expect(other.values, {
        AutofillField.trackTotal: 12,
        AutofillField.genre: 'Jazz',
      });
      expect(other.leftForMissingNumber, isEmpty);
    });

    test('GivenTheDiscNumberClearedWhileAFileHoldsADiscTotal_WhenEditsAreWorkedOut_ThenThePairIsLeftAndNoted', () {
      final files = [
        file(
          values: const {
            AutofillField.discNumber: 1,
            AutofillField.discTotal: 2,
          },
        ),
        file(
          values: const {
            AutofillField.discNumber: 1,
            AutofillField.discTotal: 2,
          },
        ),
      ];
      final shared = SharedTags.of(files);
      final form = formWith(shared, {AutofillField.discNumber: ''});

      final edits = editsFor(files.first, shared, form);
      expect(edits.values, isNot(contains(AutofillField.discNumber)));
      expect(edits.values, isNot(contains(AutofillField.discTotal)));
      expect(edits.leftForMissingNumber, {AutofillField.discTotal});
    });

    test('GivenAFileHoldingATotalWithNoNumber_WhenOtherFieldsChange_ThenNothingIsNoted', () {
      final f = file(values: const {AutofillField.trackTotal: 12});
      final shared = SharedTags.of([f, f]);
      final form = formWith(shared, {AutofillField.genre: 'Jazz'});

      final edits = editsFor(f, shared, form);
      expect(edits.values, {AutofillField.genre: 'Jazz'});
      expect(edits.leftForMissingNumber, isEmpty);
    });

    test('GivenAnInvalidNumber_WhenEditsAreWorkedOut_ThenItIsNotWritten', () {
      final f = file();
      final shared = SharedTags.of([f, f]);
      final form = formWith(shared, {AutofillField.year: '10000'});

      expect(editsFor(f, shared, form).values, isEmpty);
    });
  });

  group('sharedNumberProblems', () {
    test('GivenAYearOf10000_WhenChecked_ThenItIsAProblem', () {
      final shared = SharedTags.of([file(), file()]);
      final form = formWith(shared, {AutofillField.year: '10000'});

      expect(sharedNumberProblems(shared, form), {
        AutofillField.year: NumberProblem.yearOutOfRange,
      });
    });

    test('GivenAMixedNumberLeftBlank_WhenChecked_ThenItIsNoProblem', () {
      final shared = SharedTags.of([
        file(values: const {AutofillField.year: 1997}),
        file(values: const {AutofillField.year: 2000}),
      ]);
      final form = formWith(shared, const {});

      expect(sharedNumberProblems(shared, form), isEmpty);
    });

    test('GivenATrackTotalOfZero_WhenChecked_ThenItIsNotAWholeNumber', () {
      final shared = SharedTags.of([file(), file()]);
      final form = formWith(shared, {AutofillField.trackTotal: '0'});

      expect(sharedNumberProblems(shared, form), {
        AutofillField.trackTotal: NumberProblem.notAWholeNumber,
      });
    });
  });

  group('hasSharedChanges', () {
    test('GivenNothingTyped_WhenAskedForChanges_ThenThereAreNone', () {
      final shared = SharedTags.of([
        file(values: const {AutofillField.album: 'OK Computer'}),
        file(values: const {AutofillField.album: 'OK Computer'}),
      ]);

      expect(hasSharedChanges(shared, formWith(shared, const {})), isFalse);
    });

    test(
      'GivenAFieldOnlyPaddedWithSpaces_WhenAskedForChanges_ThenThereAreNone',
      () {
        final shared = SharedTags.of([
          file(values: const {AutofillField.album: 'OK Computer'}),
          file(values: const {AutofillField.album: 'OK Computer'}),
        ]);
        final form = formWith(shared, {AutofillField.album: ' OK Computer  '});

        expect(hasSharedChanges(shared, form), isFalse);
      },
    );

    test('GivenATypedValue_WhenAskedForChanges_ThenThereAreChanges', () {
      final shared = SharedTags.of([file(), file()]);
      final form = formWith(shared, {AutofillField.genre: 'Jazz'});

      expect(hasSharedChanges(shared, form), isTrue);
    });

    test('GivenRemoveCover_WhenAskedForChanges_ThenThereAreChanges', () {
      final shared = SharedTags.of([file(cover: png), file()]);
      final form = formWith(shared, const {}, cover: const RemoveCover());

      expect(hasSharedChanges(shared, form), isTrue);
    });

    test('GivenReplaceCover_WhenAskedForChanges_ThenThereAreChanges', () {
      final shared = SharedTags.of([file(), file()]);
      final form = formWith(shared, const {}, cover: ReplaceCover(png));

      expect(hasSharedChanges(shared, form), isTrue);
    });
  });
}
