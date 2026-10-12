import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/presentation/autofill_fields_dialog.dart';

import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Choosing which tags to fill.
void main() {
  Set<AutofillField>? chosen;

  Future<void> open(WidgetTester tester, {Set<AutofillField>? initial, bool anyWritable = true}) async {
    chosen = null;
    await tester.pumpHarness(
      Harness(),
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => chosen = await AutofillFieldsDialog.ask(
            context,
            initial: initial ?? AutofillField.defaults,
            anyWritable: anyWritable,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('GivenTheDefaults_WhenTheDialogOpens_ThenEveryTagButTheCoverIsTicked', (tester) async {
    await open(tester);

    CheckboxListTile tile(String label) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label));
    expect(tile('Artist').value, isTrue);
    expect(tile('Cover art').value, isFalse);
  });

  testWidgets('GivenTheOwnerTicksTheCover_WhenTheyFind_ThenTheirChoiceComesBack', (tester) async {
    await open(tester, initial: {AutofillField.artist});

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cover art'));
    await tester.pump();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(chosen, {AutofillField.artist, AutofillField.cover});
  });

  testWidgets('GivenEveryTagIsUnticked_WhenTheDialogShows_ThenFindIsDisabled', (tester) async {
    await open(tester, initial: {AutofillField.artist});

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Artist'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Find')).onPressed, isNull);
  });

  testWidgets('GivenNoFileCanBeWritten_WhenTheDialogOpens_ThenItSaysSoAndOffersNothingToFind', (tester) async {
    await open(tester, anyWritable: false);

    expect(find.textContaining('MP3 and FLAC'), findsOneWidget);
    expect(find.text('Find'), findsNothing);
  });
}
