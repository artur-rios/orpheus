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
      fileName: safeFileName(suggestedName),
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

/// [name] with what a file name may not contain made harmless.
///
/// A playlist is called whatever its owner likes — "AC/DC", "Rock: 70s" — and
/// the file it is exported to is named after it. Windows refuses names with
/// `< > : " / \ | ? *` or control characters, and the Windows save dialog
/// does not report that: it throws inside an isolate nobody listens to, and
/// the dialog never returns. So each of those becomes `_`, and the dots and
/// spaces Windows also refuses at the end of a name are trimmed, before the
/// name goes anywhere near it. A name with nothing left is `_`.
String safeFileName(String name) {
  final replaced = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
  final trimmed = replaced
      .replaceAll(RegExp(r'^\s+'), '')
      .replaceAll(RegExp(r'[. ]+$'), '');

  return trimmed.isEmpty ? '_' : trimmed;
}
