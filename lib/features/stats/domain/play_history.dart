/// How long the dates of a track's plays are kept.
///
/// The counts are kept for ever; the dates only for this long. Long enough for
/// anything that asks what the owner has been listening to *lately* — the
/// auto playlists look back 30 days — and short enough that the history stays
/// proportional to the music played in one season rather than to every play
/// ever made.
const Duration recentPlaysKept = Duration(days: 90);

/// How often one file has been played, and when it last was.
class TrackPlays {
  /// Creates a record.
  const TrackPlays({
    required this.path,
    required this.plays,
    required this.lastPlayedAt,
    this.recent = const [],
  });

  /// The file, identified as it is everywhere else in this application.
  final String path;

  /// How many times it has counted as played.
  final int plays;

  /// When it last did.
  final DateTime lastPlayedAt;

  /// When it was played within the last [recentPlaysKept], in UTC, oldest
  /// first.
  ///
  /// Not every play: only those recorded since plays were dated, and only the
  /// recent ones — see [PlayHistory.trimmedTo]. [plays] is the count, and is
  /// usually more than this holds.
  final List<DateTime> recent;

  /// This record, one play later at [at].
  TrackPlays plusOne(DateTime at) => TrackPlays(
    path: path,
    plays: plays + 1,
    lastPlayedAt: at,
    recent: _inserted(recent, at.toUtc()),
  );

  /// This record without the dates before [cutoff]; itself when there are
  /// none.
  TrackPlays _since(DateTime cutoff) {
    // Oldest first, so the dates to drop are a prefix.
    final kept = recent.indexWhere((at) => !at.isBefore(cutoff));
    if (recent.isEmpty || kept == 0) return this;

    return TrackPlays(
      path: path,
      plays: plays,
      lastPlayedAt: lastPlayedAt,
      recent: kept < 0 ? const [] : List.unmodifiable(recent.sublist(kept)),
    );
  }

  /// [dates] with [at] in its place, keeping them oldest first.
  ///
  /// Nearly always at the end. A clock set back — by the owner, or by a
  /// machine that synchronised its time — is the exception, and the order is
  /// kept even then so that trimming can stop at the first date it keeps.
  static List<DateTime> _inserted(List<DateTime> dates, DateTime at) {
    final place = dates.lastIndexWhere((date) => !date.isAfter(at)) + 1;

    return List.unmodifiable([
      ...dates.take(place),
      at,
      ...dates.skip(place),
    ]);
  }
}

/// What this application has recorded about what was listened to.
///
/// A count per file, not a row per play, and the difference is deliberate: a
/// count per file keeps the document proportional to the number of *tracks
/// ever played* rather than to the number of plays, which is what stops a
/// history growing without bound on a machine nobody prunes. The statistics
/// read the counts alone, and offer no time windows — see the statistics
/// screen.
///
/// Beside each count, the dates of the track's last [recentPlaysKept] of
/// plays ([TrackPlays.recent]), for what asks about *lately*. Bounded by the
/// window rather than by nothing, which keeps the promise above: dates older
/// than it are trimmed whenever the history is read or written.
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

  /// This history with one more play of [path] at [at], its date included in
  /// the track's [TrackPlays.recent].
  PlayHistory recording(String path, DateTime at) {
    final existing = tracks[path];

    return PlayHistory(
      tracks: {
        ...tracks,
        path:
            existing?.plusOne(at) ??
            TrackPlays(
              path: path,
              plays: 1,
              lastPlayedAt: at,
              recent: List.unmodifiable([at.toUtc()]),
            ),
      },
    );
  }

  /// This history without the dates of plays more than [recentPlaysKept]
  /// before [now], on every track.
  ///
  /// Only dates go: every track stays, with its count and its last play. A
  /// date exactly [recentPlaysKept] old is kept.
  PlayHistory trimmedTo(DateTime now) {
    final cutoff = now.subtract(recentPlaysKept);

    return PlayHistory(
      tracks: {
        for (final track in tracks.entries)
          track.key: track.value._since(cutoff),
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
