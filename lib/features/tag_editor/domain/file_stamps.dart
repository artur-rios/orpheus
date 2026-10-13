import '../../library/domain/audio_file.dart';

/// What a file on disk is now: its size and its modification time.
///
/// What a tag edit measures "changed since it was read" against. Not the
/// catalog's copy of the file, which only a rescan refreshes: a second save
/// made before that rescan lands would be measured against a file that no
/// longer exists. Behind an interface so no test touches a real file.
abstract interface class FileStamps {
  /// The file at [path] as it is now. Throws where it cannot be read.
  Future<AudioFile> stamp(String path);
}
