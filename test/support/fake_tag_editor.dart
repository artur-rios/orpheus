import 'dart:typed_data';

import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/tag_editor/domain/cover_picker.dart';
import 'package:orpheus/features/tag_editor/domain/file_stamps.dart';

/// [FileStamps] answering what the test set, and recording what was stamped.
class FakeFileStamps implements FileStamps {
  /// What each path is stamped as. A path not here is stamped with the size
  /// and time `file()` in `entries.dart` gives every test file.
  final Map<String, AudioFile> stamps = {};

  /// Every path stamped, in order.
  final List<String> stamped = [];

  @override
  Future<AudioFile> stamp(String path) async {
    stamped.add(path);

    return stamps[path] ??
        AudioFile(
          path: path,
          sizeInBytes: 1024,
          modifiedAt: DateTime.utc(2026),
        );
  }
}

/// A [CoverPicker] answering [next].
class FakeCoverPicker implements CoverPicker {
  /// What the owner will pick; `null` is a dismissed dialog.
  Uint8List? next;

  /// How many times the dialog was opened.
  int picks = 0;

  @override
  Future<Uint8List?> pickImage() async {
    picks++;

    return next;
  }
}
