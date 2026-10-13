import 'dart:io';

import '../../library/domain/audio_file.dart';
import '../domain/file_stamps.dart';

/// [FileStamps] over `dart:io`, the same `stat` the tag writer checks a file
/// against before it writes.
class IoFileStamps implements FileStamps {
  /// Creates the stamps.
  const IoFileStamps();

  @override
  Future<AudioFile> stamp(String path) async {
    final stat = await File(path).stat();
    if (stat.type == FileSystemEntityType.notFound) {
      throw FileSystemException('There is no file here', path);
    }

    return AudioFile(
      path: path,
      sizeInBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }
}
