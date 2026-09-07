/// Everything that can go wrong, as the interface needs to know it.
///
/// A closed set rather than exceptions passed around: the screens have to turn
/// a failure into a sentence a listener can read, and a sentence per exception
/// type is a sentence written wherever the exception happened to be caught.
sealed class Failure implements Exception {
  /// Creates a failure carrying [cause], the underlying error where there was
  /// one.
  const Failure({this.cause});

  /// What was actually thrown, for the log. Never for the screen.
  final Object? cause;
}

/// The catalog document could not be written.
///
/// Writing only. A catalog that cannot be *read* is not a failure anyone is
/// shown: it is answered with an empty library and a re-scan, which is the
/// same place a first launch starts from. A catalog that cannot be written is
/// different — the scan the owner just waited through will have to run again
/// next launch, and they are owed that.
class CatalogUnavailable extends Failure {
  /// Creates the failure.
  const CatalogUnavailable({super.cause});
}

/// The platform refused access to the owner's audio files.
///
/// Android only: the two desktops have no such gate, and a permission that is
/// never asked for cannot be denied.
class StoragePermissionDenied extends Failure {
  /// Creates the failure.
  ///
  /// [permanently] is the difference between a question the owner can be asked
  /// again and one the system will no longer put to them — which is the
  /// difference between offering a retry and offering the settings screen.
  const StoragePermissionDenied({this.permanently = false, super.cause});

  /// Whether the system will refuse to ask again.
  final bool permanently;
}

/// Anything the application did not model.
///
/// A bug rather than a condition, which is why it carries no detail beyond its
/// cause: there is nothing specific to say to the owner about it.
class UnexpectedFailure extends Failure {
  /// Creates the failure.
  const UnexpectedFailure({super.cause});
}
