import 'dart:typed_data';

/// Asks the owner where to put a file, and puts it there.
abstract interface class FileSaver {
  /// Offers [suggestedName] to the owner and saves [bytes] where they say.
  ///
  /// Returns where it went, or `null` when the owner cancelled, which is not
  /// a failure. Throws when the file could not be saved.
  Future<SavedFile?> save({
    required String suggestedName,
    required Uint8List bytes,
  });
}

/// A file that was saved, and its path when there is one to tell the owner.
class SavedFile {
  /// Creates the result of a save; [path] `null` is a place with no path.
  const SavedFile({this.path});

  /// The file's path, or `null` when the platform put it somewhere it has no
  /// path for — Android's document provider answers with a `content://`
  /// address, which means nothing to the owner and is not worth showing.
  final String? path;
}
