import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/cover_picker.dart';

/// [CoverPicker] over `file_picker`: the platform's image chooser on all three
/// targets, the same package the folder picker uses.
class FilePickerCoverPicker implements CoverPicker {
  /// Creates the picker.
  const FilePickerCoverPicker();

  @override
  Future<Uint8List?> pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);

    return file?.readAsBytes();
  }
}
