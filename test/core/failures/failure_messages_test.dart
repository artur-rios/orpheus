import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/failures/failure.dart';
import 'package:orpheus/core/failures/failure_messages.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';

/// What each failure says on screen.
///
/// The one place a failure becomes a sentence, so a permission that will not
/// be asked for again must not read like one that can be retried.
void main() {
  for (final (language, locale) in [
    ('English', const Locale('en')),
    ('Portuguese', const Locale('pt', 'BR')),
  ]) {
    final l10n = lookupAppLocalizations(locale);

    test(
      'GivenAnUnwritableCatalogIn${language}_WhenNamed_ThenItSaysTheCatalogIsUnavailable',
      () {
        expect(
          const CatalogUnavailable().localizedMessage(l10n),
          l10n.failureCatalogUnavailable,
        );
      },
    );

    test(
      'GivenARefusedPermissionIn${language}_WhenNamed_ThenItSaysItCanBeAskedAgain',
      () {
        expect(
          const StoragePermissionDenied().localizedMessage(l10n),
          l10n.failurePermissionDenied,
        );
      },
    );

    test(
      'GivenAPermanentlyRefusedPermissionIn${language}_WhenNamed_ThenItSaysSoAndNotThatItCanBeRetried',
      () {
        expect(
          const StoragePermissionDenied(
            permanently: true,
          ).localizedMessage(l10n),
          l10n.failurePermissionDeniedPermanently,
        );
        expect(
          l10n.failurePermissionDeniedPermanently,
          isNot(l10n.failurePermissionDenied),
        );
      },
    );

    test(
      'GivenAnUnexpectedFailureIn${language}_WhenNamed_ThenItSaysSomethingWentWrong',
      () {
        expect(
          UnexpectedFailure(cause: StateError('boom')).localizedMessage(l10n),
          l10n.failureUnexpected,
        );
      },
    );
  }
}
