import 'package:path/path.dart' as p;

/// One audio file on disk, as everything above the scanner knows it.
///
/// Identified by its path. There is no catalog server to mint an id and no
/// database to hold one, and a path is what every other part of this
/// application — the player, the cover store, the resume positions — has to
/// have anyway. The consequence is stated rather than hidden: moving a file
/// makes it a different track to this application, and re-scanning is what
/// reconciles that.
class AudioFile {
  /// Creates a file.
  const AudioFile({
    required this.path,
    required this.sizeInBytes,
    required this.modifiedAt,
  });

  /// Its absolute path.
  final String path;

  /// How large it is, which is half of what tells a re-scan whether the file
  /// changed.
  final int sizeInBytes;

  /// When it was last written, which is the other half.
  final DateTime modifiedAt;

  /// What identifies this file everywhere else in the application.
  String get id => path;

  /// Its name on disk.
  ///
  /// Shown nowhere the owner browses music — a track is named by its tags, and
  /// that is the whole point of the music area. It is here because a file with
  /// no tags at all still has to sort somewhere deterministic, and because the
  /// library screen names the files a scan could not read.
  String get name => p.basename(path);

  /// The folder holding it, which is where a sidecar cover would be.
  String get directory => p.dirname(path);

  @override
  bool operator ==(Object other) => other is AudioFile && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'AudioFile($path)';
}
