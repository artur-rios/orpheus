import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';

/// The batch autofill's counts, which a whole library makes run into the
/// thousands, grouped as each language groups digits.
void main() {
  late AppLocalizations en;
  late AppLocalizations pt;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  test('GivenThousandsOfSongs_WhenTheConfirmationIsRead_ThenGrouped', () {
    expect(en.autofillBatchConfirmTitle(3412), 'Autofill 3,412 songs?');
    expect(pt.autofillBatchConfirmTitle(3412), 'Preencher 3.412 faixas?');
    expect(
      en.autofillBatchConfirmSkipped(1240),
      "1,240 songs can't be changed and will be skipped.",
    );
  });

  test('GivenThousandsOfRecords_WhenTheProgressIsRead_ThenGrouped', () {
    expect(
      en.autofillBatchProgress(1037, 2880),
      'Looking up 1,037 of 2,880 records',
    );
    expect(
      pt.autofillBatchProgress(1037, 2880),
      'Buscando 1.037 de 2.880 discos',
    );
    expect(
      en.autofillBatchIndicatorRunning(1037, 2880),
      'Autofilling 1,037/2,880',
    );
  });

  test('GivenThousandsCounted_WhenTheSummaryIsRead_ThenGrouped', () {
    expect(en.autofillBatchSkipped(1240), '1,240 skipped');
    expect(pt.autofillBatchSkipped(1240), '1.240 ignorados');
    expect(
      en.autofillBatchSummary(2410, 1045),
      '2,410 records updated, 1,045 need you',
    );
  });

  test('GivenAFewCounted_WhenRead_ThenUnchanged', () {
    expect(en.autofillBatchUpdated(3), '3 updated');
    expect(en.autofillDoubtUnmatchedSongs(1), '1 song unmatched');
    expect(pt.autofillBatchNeedYou(0), '0 precisam de você');
  });
}
