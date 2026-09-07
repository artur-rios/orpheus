import 'lyrics.dart';

/// What is known about a track when its words are looked for elsewhere.
///
/// Tags rather than a path, deliberately: the file's name is the one thing a
/// lyrics service cannot use, and it is also the one thing that would say
/// something about this machine — a folder tree, a user name — to a server
/// that has no business knowing it. What leaves is the artist and the title,
/// which is what is printed on the sleeve.
class LyricsQuery {
  /// Creates a query.
  const LyricsQuery({
    required this.title,
    required this.artist,
    this.album,
    this.duration,
  });

  /// The track's title, as its tags give it.
  final String title;

  /// Who performed it.
  final String artist;

  /// The record it is on, where the tags name one.
  ///
  /// Optional because half-tagged libraries are the norm, and a lookup that
  /// insisted on it would answer nothing for a large share of real libraries.
  final String? album;

  /// How long the track is, where the tags say.
  ///
  /// The field that separates a match from a near-match: two recordings of the
  /// same song by the same artist — the studio take and the live one — carry
  /// the same title and the same artist and different times per line, and the
  /// length is what tells them apart.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is LyricsQuery &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(title, artist, album, duration);

  @override
  String toString() => 'LyricsQuery($artist — $title)';
}

/// A sheet found away from this machine.
///
/// Carries both forms on purpose. [lyrics] is what the panel draws; [text] is
/// the LRC exactly as it arrived, and it is that — not a re-rendering of the
/// parsed lines — that gets written beside the track. A round trip through
/// this application's own parser would quietly drop everything it chooses not
/// to model: the per-word times of enhanced LRC, the `[ti:]` and `[ar:]`
/// headers, the writer's own credit. What lands on disk is the sheet somebody
/// actually wrote.
class RemoteLyrics {
  /// Creates a found sheet.
  const RemoteLyrics({required this.lyrics, required this.text});

  /// The words, parsed.
  final Lyrics lyrics;

  /// The LRC as it arrived, byte for byte.
  final String text;
}

/// Where a track's words are looked for when this machine holds none.
///
/// The one seam in this application that reaches a network, and it is narrow
/// on purpose: tags in, a sheet or nothing out. Nothing about the machine, the
/// library, the owner or what else they listen to crosses it, and it is only
/// ever reached after [LyricsSource] has answered `null` — the owner's own
/// files always win.
///
/// Answering `null` is the ordinary case, not a failure: most tracks are not
/// in any lyrics database. A network that cannot be reached answers `null`
/// too, for the same reason the local source does when a tag will not parse —
/// a track with no words on screen is a fact the panel already knows how to
/// show, and it is not worth a dialog over.
abstract interface class RemoteLyricsSource {
  /// The words for [query], or `null` where none were found.
  Future<RemoteLyrics?> find(LyricsQuery query);
}
