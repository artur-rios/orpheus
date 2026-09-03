import 'dart:io';

import '../domain/track_probe.dart';

/// [TrackProbe] against the filesystem.
class FileTrackProbe implements TrackProbe {
  /// Creates a probe.
  const FileTrackProbe();

  @override
  bool exists(String path) {
    try {
      return File(path).existsSync();
    } on Object {
      // A path the process may not even stat is a path it cannot play, which
      // is the same answer as one that is not there.
      return false;
    }
  }
}
