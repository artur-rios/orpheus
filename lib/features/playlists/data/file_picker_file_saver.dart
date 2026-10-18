import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../domain/file_saver.dart';

/// [FileSaver] over `file_picker`: the platform's save dialog on all three
/// targets, the same package the other pickers use.
///
/// The package writes the bytes itself — to the file chosen on the desktop,
/// and through the system's document provider on Android and iOS — so this
/// writes nothing of its own: a second write to the path it hands back would
/// only be a way to put something else than what the owner approved there.
class FilePickerFileSaver implements FileSaver {
  /// Creates the saver.
  const FilePickerFileSaver();

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: bytes,
      mimeType: _mimeTypeOf(suggestedName),
    );
    if (saved == null) return null;

    return saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
  }

  /// What the platform should be told the file is, where it asks: Android
  /// names the file after its type and would otherwise give a playlist an
  /// extension of its own choosing.
  static String _mimeTypeOf(String fileName) =>
      switch (p.extension(fileName).toLowerCase()) {
        '.m3u' || '.m3u8' => 'audio/x-mpegurl',
        _ => 'application/octet-stream',
      };
}
