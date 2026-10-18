import 'dart:typed_data';

/// Asks the owner where to put a file, and puts it there.
abstract interface class FileSaver {
  /// Offers [suggestedName] to the owner and saves [bytes] where they say.
  ///
  /// Returns where it went — a path, or the platform's name for the place when
  /// it has no path to give — or `null` when the owner cancelled, which is not
  /// a failure. Throws when the file could not be saved.
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
  });
}
