import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';

/// Which tags an autofill offers, and how the owner's last choice is kept.
void main() {
  test(
    'GivenNothingStored_WhenTheChoiceIsRead_ThenEveryTagButTheCoverIsTicked',
    () {
      final fields = AutofillField.decode(null);

      expect(fields, AutofillField.defaults);
      expect(fields, isNot(contains(AutofillField.cover)));
      expect(fields, hasLength(AutofillField.values.length - 1));
    },
  );

  test('GivenAChoiceWasStored_WhenItIsReadBack_ThenItIsTheSameChoice', () {
    const chosen = {AutofillField.artist, AutofillField.cover};

    expect(AutofillField.decode(AutofillField.encode(chosen)), chosen);
  });

  test('GivenAStoredNameThisVersionDoesNotKnow_WhenTheChoiceIsRead_ThenItIsIgnored', () {
    expect(AutofillField.decode('artist,mood'), {AutofillField.artist});
  });

  test('GivenAnEmptyStoredChoice_WhenItIsRead_ThenTheDefaultsAreOffered', () {
    // An empty choice is not one the dialog lets anybody confirm; one that
    // was stored anyway is treated as nothing stored.
    expect(AutofillField.decode(''), AutofillField.defaults);
  });
}
