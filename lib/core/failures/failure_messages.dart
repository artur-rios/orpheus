import '../l10n/generated/app_localizations.dart';
import 'failure.dart';

/// What each failure says on screen.
///
/// In the presentation's own layer rather than on the failure classes: a
/// failure is a fact about what happened, and the sentence describing it is a
/// translated string that the domain has no business holding.
extension FailureMessage on Failure {
  /// The sentence for this failure, in the active language.
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    LibraryFolderUnreadable(:final path) => l10n.failureFolderUnreadable(path),
    CatalogUnavailable() => l10n.failureCatalogUnavailable,
    StoragePermissionDenied(permanently: true) =>
      l10n.failurePermissionDeniedPermanently,
    StoragePermissionDenied() => l10n.failurePermissionDenied,
    TrackUnplayable(:final path) => l10n.failureTrackUnplayable(path),
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}
