import 'dart:typed_data';

/// Asks the owner for a file, and reads it.
abstract interface class FileOpener {
  /// Offers the owner the files whose names end in one of [extensions]
  /// (without the dot: `zip`, `json`) and answers the bytes of the one they
  /// picked.
  ///
  /// Returns `null` when the owner cancelled, which is not a failure. Throws
  /// when the file could not be read.
  Future<Uint8List?> open({required List<String> extensions});
}
