import 'dart:typed_data';

/// Asks the owner for a picture to use as a cover, with the platform's own
/// dialog.
///
/// Behind an interface because a native dialog cannot be opened in a widget
/// test, and "the owner chose a new cover" is a flow worth testing.
abstract interface class CoverPicker {
  /// The bytes of the image the owner chose, or `null` where they dismissed
  /// the dialog.
  Future<Uint8List?> pickImage();
}
