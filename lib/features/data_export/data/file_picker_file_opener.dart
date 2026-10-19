import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/file_opener.dart';

/// [FileOpener] over `file_picker`: the platform's open dialog on all three
/// targets, the same package the other pickers use.
///
/// The bytes are read through the picked file rather than from a path,
/// because on Android the file comes from the system's document provider and
/// has no path this application could open.
class FilePickerFileOpener implements FileOpener {
  /// Creates the opener.
  const FilePickerFileOpener();

  @override
  Future<Uint8List?> open({required List<String> extensions}) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    return picked?.readAsBytes();
  }
}
