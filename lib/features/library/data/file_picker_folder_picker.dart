import 'package:file_picker/file_picker.dart';

import '../domain/library_access.dart';

/// [FolderPicker] over `file_picker`.
///
/// The platform's own dialog on all three targets — the Windows and GTK folder
/// choosers, and the Android document picker — which is what makes a folder
/// the owner chose one they recognise rather than a path they had to type.
class FilePickerFolderPicker implements FolderPicker {
  /// Creates the picker.
  const FilePickerFolderPicker();

  @override
  Future<String?> pickFolder() => FilePicker.getDirectoryPath();
}
