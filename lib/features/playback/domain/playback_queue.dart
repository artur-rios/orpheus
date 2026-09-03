import '../../library/domain/audio_file.dart';

/// What the owner asked to play.
enum QueueKind {
  /// One track.
  track,

  /// Every track on an album, in order.
  album,

  /// Every track by an artist.
  artist,

  /// A sequence with a name and no record of its own — what shuffling the
  /// whole library produces.
  playlist,
}

/// What happens when the queue runs out.
enum QueueRepeat {
  /// Nothing. Playback stops at the end of the last track.
  off,

  /// The queue starts again from its first track.
  all,

  /// The track playing repeats until the owner says otherwise.
  one;

  /// The mode after this one, which is what pressing the button does.
  QueueRepeat get next => switch (this) {
    QueueRepeat.off => QueueRepeat.all,
    QueueRepeat.all => QueueRepeat.one,
    QueueRepeat.one => QueueRepeat.off,
  };
}

/// The tracks queued for playback, and where in them playback is.
class PlaybackQueue {
  /// Creates a queue over [tracks], starting at [index].
  const PlaybackQueue({
    required this.tracks,
    required this.kind,
    this.label,
    this.year,
    this.index = 0,
    this.skipped = const [],
  });

  /// An empty queue, which is what stopping leaves behind.
  static const PlaybackQueue empty = PlaybackQueue(
    tracks: [],
    kind: QueueKind.track,
  );

  /// The tracks, in the order they will play.
  final List<AudioFile> tracks;

  /// What the owner asked for.
  final QueueKind kind;

  /// The album or artist name, or `null` — for a single track, where the
  /// presentation layer shows the track's own title beside this label instead;
  /// for an album or an artist whose tags name none, where an absent label
  /// means the *tag* is absent. Neither the application layer that builds this
  /// queue nor this domain class has the localized strings to turn that
  /// absence into a word, so this class only carries it; the presentation
  /// layer decides what to say.
  final String? label;

  /// The year the album carries.
  final int? year;

  /// Which track is playing.
  final int index;

  /// The tracks that could not be played, in the order they were skipped.
  final List<AudioFile> skipped;

  /// Whether there is anything queued at all.
  bool get isEmpty => tracks.isEmpty;

  /// The track playing now, or `null` when the queue is empty or finished.
  AudioFile? get current =>
      index >= 0 && index < tracks.length ? tracks[index] : null;

  /// Whether there is a track after this one.
  bool get hasNext => index + 1 < tracks.length;

  /// Whether there is a track before this one.
  bool get hasPrevious => index > 0;

  /// Whether every queued track was skipped.
  bool get everythingFailed =>
      tracks.isNotEmpty && skipped.length == tracks.length;

  /// Whether the record playing is the queue's own, rather than the current
  /// track's.
  ///
  /// An album or an artist queue *is* a record: it carries the label and the
  /// year that identify it, and every track in it belongs to the same one.
  ///
  /// A track queue and a playlist queue are not. A lone track's record is
  /// whatever that track's own tags say it is; a playlist's is the same
  /// question asked again on every track, because a playlist deliberately
  /// names no record of its own — which is what makes crossing from one album
  /// to the next inside one change the sleeve on the bar, while skipping
  /// within an album does not.
  bool get namesOwnRecord => switch (kind) {
    QueueKind.album || QueueKind.artist => true,
    QueueKind.track || QueueKind.playlist => false,
  };

  /// A copy with the given changes.
  PlaybackQueue copyWith({
    List<AudioFile>? tracks,
    QueueKind? kind,
    String? label,
    int? year,
    int? index,
    List<AudioFile>? skipped,
  }) => PlaybackQueue(
    tracks: tracks ?? this.tracks,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    year: year ?? this.year,
    index: index ?? this.index,
    skipped: skipped ?? this.skipped,
  );

  /// The queue with [file] recorded as unplayable.
  PlaybackQueue skipping(AudioFile file) =>
      copyWith(skipped: [...skipped, file]);
}
