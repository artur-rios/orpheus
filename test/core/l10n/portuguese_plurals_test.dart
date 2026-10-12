import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';

/// Counts in Portuguese.
///
/// Portuguese files zero under "one", so a plural that names only `=1` and
/// `other` renders a count of nothing as "1".
void main() {
  test(
    'GivenNothingToWrite_WhenTheButtonIsRead_ThenPortugueseSaysZero',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));

      expect(l10n.autofillWrite(0, 0), 'Gravar 0 alterações em 0 arquivos');
      expect(l10n.autofillWrite(1, 1), 'Gravar 1 alteração em 1 arquivo');
      expect(l10n.autofillWrite(3, 2), 'Gravar 3 alterações em 2 arquivos');
    },
  );
}
