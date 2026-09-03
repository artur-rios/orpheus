import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import 'play_history.dart';

/// One line of a ranking: something with a name, and how often it was played.
class RankedPlays {
  /// Creates a line.
  const RankedPlays({required this.name, required this.plays});

  /// What it is called.
  final String name;

  /// How many plays it accounts for.
  final int plays;
}

/// What the owner listens to.
///
/// Built by reading the play history against the catalog rather than stored,
/// so a library that gets re-tagged gets a corrected history for free.
class MusicStats {
  /// Creates the statistics.
  const MusicStats({
    required this.totalPlays,
    required this.distinctTracks,
    required this.tracks,
    required this.artists,
    required this.albums,
    required this.genres,
    required this.untaggedTracks,
  });

  /// Nothing played yet.
  static const MusicStats empty = MusicStats(
    totalPlays: 0,
    distinctTracks: 0,
    tracks: [],
    artists: [],
    albums: [],
    genres: [],
    untaggedTracks: 0,
  );

  /// Every play ever counted.
  final int totalPlays;

  /// How many distinct files account for them.
  final int distinctTracks;

  /// The most played tracks, most first.
  final List<RankedPlays> tracks;

  /// The most played artists, most first.
  final List<RankedPlays> artists;

  /// The most played records, most first.
  final List<RankedPlays> albums;

  /// The most played genres, most first.
  final List<RankedPlays> genres;

  /// How many played files carry no artist, record or genre tag.
  ///
  /// Counted so the screen can say why its totals are larger than its
  /// rankings. Without it, seven plays above three artists is a discrepancy
  /// with no explanation anywhere on screen.
  final int untaggedTracks;

  /// Whether nothing has been played.
  bool get isEmpty => totalPlays == 0;
}

/// How many lines each ranking carries.
const int rankingLength = 10;

/// The statistics [history] and [catalog] describe between them.
///
/// Three rules are worth stating, because each one is a decision:
///
/// 1. **A file the catalog no longer holds still counts.** Its plays happened.
///    It contributes to the totals and to the track ranking under its name on
///    disk, and to nothing else, because there are no tags left to rank it by.
/// 2. **An absent tag ranks nowhere rather than under a word.** A track with
///    no artist tag is not an artist called "Unknown" — that is a bug wearing a
///    fact's clothes, and it would sit at the top of the owner's chart. It is
///    counted in [MusicStats.untaggedTracks] instead, and the screen says so.
/// 3. **A track with no title is named by its file.** The one place in this
///    application that names a file on disk rather than by its tags, and for
///    the same reason the folders screen does it: the alternative is ten rows
///    all called "Untitled", which is a ranking nobody can read.
MusicStats musicStatsFrom({
  required PlayHistory history,
  required MusicCatalog catalog,
  int limit = rankingLength,
}) {
  if (history.isEmpty) return MusicStats.empty;

  final tracks = <String, int>{};
  final artists = <String, int>{};
  final albums = <String, int>{};
  final genres = <String, int>{};
  var untagged = 0;

  for (final played in history.tracks.values) {
    final entry = catalog.entryAt(played.path);
    final plays = played.plays;

    // Named by its title, or by the file when the tags carry none — see rule 3.
    tracks.update(
      entry?.title ?? _fileNameOf(played.path),
      (existing) => existing + plays,
      ifAbsent: () => plays,
    );

    final artist = entry?.albumArtist;
    final album = entry?.album;
    // Through the same trimming rule every other tag in the application
    // reads by, so a genre of three spaces is absent here too.
    final genre = trimmedOrNull(entry?.metadata.genre);

    if (artist == null && album == null && genre == null) untagged++;

    if (artist != null) {
      artists.update(artist, (e) => e + plays, ifAbsent: () => plays);
    }
    if (album != null) {
      albums.update(album, (e) => e + plays, ifAbsent: () => plays);
    }
    if (genre != null) {
      genres.update(genre, (e) => e + plays, ifAbsent: () => plays);
    }
  }

  return MusicStats(
    totalPlays: history.totalPlays,
    distinctTracks: history.distinctTracks,
    tracks: _ranked(tracks, limit),
    artists: _ranked(artists, limit),
    albums: _ranked(albums, limit),
    genres: _ranked(genres, limit),
    untaggedTracks: untagged,
  );
}

/// [counts] as the top [limit] lines, most played first.
///
/// Ties break by name, so a ranking is the same list every time it is read
/// rather than one whose equal rows swap places between openings.
List<RankedPlays> _ranked(Map<String, int> counts, int limit) {
  final lines = [
    for (final entry in counts.entries)
      RankedPlays(name: entry.key, plays: entry.value),
  ]..sort((a, b) {
    final byPlays = b.plays.compareTo(a.plays);

    return byPlays != 0 ? byPlays : a.name.compareTo(b.name);
  });

  return lines.length <= limit ? lines : lines.sublist(0, limit);
}

/// The name on disk, for the one ranking that falls back to it.
String _fileNameOf(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));

  return cut < 0 ? path : path.substring(cut + 1);
}
