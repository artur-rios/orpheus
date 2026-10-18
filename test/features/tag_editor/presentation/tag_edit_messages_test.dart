import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/tag_editor/presentation/tag_edit_messages.dart';

/// What both tag editors say about a write that did not land.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('GivenEachFailedOutcome_WhenNamed_ThenItGetsItsOwnMessage', () {
    expect(
      writeOutcomeMessage(l10n, WriteOutcome.changedSinceRead),
      l10n.autofillOutcomeChanged,
    );
    expect(
      writeOutcomeMessage(l10n, WriteOutcome.inUse),
      l10n.autofillOutcomeInUse,
    );
    expect(
      writeOutcomeMessage(l10n, WriteOutcome.denied),
      l10n.autofillOutcomeDenied,
    );
    expect(
      writeOutcomeMessage(l10n, WriteOutcome.failed),
      l10n.autofillOutcomeFailed,
    );
  });

  test('GivenAnUnsupportedOutcome_WhenNamed_ThenItSaysTheTagsCannotBeChangedSafely', () {
    expect(
      writeOutcomeMessage(l10n, WriteOutcome.unsupported),
      l10n.autofillUnsafeTags,
    );
  });
}
