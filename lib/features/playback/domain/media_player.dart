/// What the engine is doing, as the interface needs to know it.
class PlaybackStatus {
  /// Creates a status.
  const PlaybackStatus({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.hasEnded = false,
    this.failedToDecode = false,
  });

  /// Whether audio is currently running.
  final bool isPlaying;

  /// Where playback is, which is what a resume position is written from.
  final Duration position;

  /// How long the file is, once the engine has worked it out.
  final Duration? duration;

  /// Whether playback reached the end of the file.
  final bool hasEnded;

  /// Whether the engine could not decode the file.
  final bool failedToDecode;

  /// A copy with the given changes.
  PlaybackStatus copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? hasEnded,
    bool? failedToDecode,
  }) => PlaybackStatus(
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    hasEnded: hasEnded ?? this.hasEnded,
    failedToDecode: failedToDecode ?? this.failedToDecode,
  );
}

/// The playback engine, as the application uses it.
///
/// Behind an interface for the usual reason and one more: the engine is a
/// native library that cannot run in a widget test, so every flow above this
/// line is testable only because this line exists.
abstract interface class MediaPlayer {
  /// What the engine is doing, as it changes.
  Stream<PlaybackStatus> get status;

  /// The last status the engine reported.
  PlaybackStatus get currentStatus;

  /// Opens [path] and begins playing from [startAt].
  Future<void> open(String path, {Duration startAt = Duration.zero});

  /// Resumes.
  Future<void> play();

  /// Pauses, leaving the position where it is.
  Future<void> pause();

  /// Moves playback to [position].
  Future<void> seek(Duration position);

  /// Stops playback and releases the file.
  Future<void> stop();

  /// Sets the output level, 0 to 1.
  Future<void> setVolume(double volume);

  /// Releases the engine.
  Future<void> dispose();
}
