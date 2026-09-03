/// Where playback of one file had got to.
class PlaybackPosition {
  /// Creates a position.
  const PlaybackPosition({
    required this.path,
    required this.position,
    required this.updatedAt,
    this.duration,
  });

  /// The file it belongs to.
  final String path;

  /// How far in playback had reached.
  final Duration position;

  /// How long the file was, where the engine had worked it out.
  final Duration? duration;

  /// When it was written, which is what lets the oldest be dropped once there
  /// are more than the store keeps.
  final DateTime updatedAt;
}

/// The resume points, across runs.
abstract interface class PlaybackPositionStore {
  /// The stored position for [path], or `null` where there is none.
  PlaybackPosition? positionFor(String path);

  /// Records [position], replacing any previous one for the same file.
  Future<void> record(PlaybackPosition position);

  /// Forgets [path], which is what a track played through to the end does.
  Future<void> forget(String path);
}
