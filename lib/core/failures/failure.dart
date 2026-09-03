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

/// A folder the owner registered is gone, or cannot be read.
class LibraryFolderUnreadable extends Failure {
  /// Creates the failure for [path].
  const LibraryFolderUnreadable({required this.path, super.cause});

  /// The folder that could not be read.
  final String path;
}

/// The catalog on disk could not be read or written.
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

/// A file the player was asked to open is missing, or will not decode.
class TrackUnplayable extends Failure {
  /// Creates the failure for [path].
  const TrackUnplayable({required this.path, super.cause});

  /// The file that would not play.
  final String path;
}

/// Anything the application did not model.
///
/// A bug rather than a condition, which is why it carries no detail beyond its
/// cause: there is nothing specific to say to the owner about it.
class UnexpectedFailure extends Failure {
  /// Creates the failure.
  const UnexpectedFailure({super.cause});
}
