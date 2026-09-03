/// How often one file has been played, and when it last was.
class TrackPlays {
  /// Creates a record.
  const TrackPlays({
    required this.path,
    required this.plays,
    required this.lastPlayedAt,
  });

  /// The file, identified as it is everywhere else in this application.
  final String path;

  /// How many times it has counted as played.
  final int plays;

  /// When it last did.
  final DateTime lastPlayedAt;

  /// This record, one play later at [at].
  TrackPlays plusOne(DateTime at) =>
      TrackPlays(path: path, plays: plays + 1, lastPlayedAt: at);
}

/// What this application has recorded about what was listened to.
///
/// A count per file rather than a row per play, and the difference is
/// deliberate. A row per play would let the rankings be re-cut by date later;
/// a count per file keeps the document proportional to the number of *tracks
/// ever played* rather than to the number of plays, which is what stops a
/// history growing without bound on a machine nobody prunes. Time windows are
/// not offered — see the statistics screen — so nothing that is offered is
/// lost by counting.
///
/// What is deliberately *not* stored here is anything a tag already says. The
/// rankings by artist, record and genre are worked out by reading this against
/// the catalog, which means re-tagging a badly tagged library corrects its
/// history rather than leaving the old names ranked forever.
class PlayHistory {
  /// Creates a history over [tracks], keyed by path.
  const PlayHistory({required this.tracks});

  /// A history with nothing in it, which is what a first launch has.
  static const PlayHistory empty = PlayHistory(tracks: {});

  /// What has been played, by the path that identifies it.
  final Map<String, TrackPlays> tracks;

  /// Every play ever counted.
  int get totalPlays {
    var total = 0;
    for (final track in tracks.values) {
      total += track.plays;
    }

    return total;
  }

  /// How many distinct files have been played at least once.
  int get distinctTracks => tracks.length;

  /// Whether nothing has been played.
  bool get isEmpty => tracks.isEmpty;

  /// This history with one more play of [path] at [at].
  PlayHistory recording(String path, DateTime at) {
    final existing = tracks[path];

    return PlayHistory(
      tracks: {
        ...tracks,
        path:
            existing?.plusOne(at) ??
            TrackPlays(path: path, plays: 1, lastPlayedAt: at),
      },
    );
  }
}

/// Where the play history is kept.
///
/// Behind an interface for the reason every other outward edge here is: a test
/// that wrote a history into the developer's own application-support folder
/// would be a test that changed their statistics.
abstract interface class PlayHistoryStore {
  /// Reads what has been recorded, or an empty history where nothing has.
  Future<PlayHistory> read();

  /// Writes [history], replacing whatever was there.
  Future<void> write(PlayHistory history);
}
