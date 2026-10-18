import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import 'play_history.dart';

/// One line of a ranking: something with a name, and how often it was played.
class RankedPlays {
  /// Creates a line.
  const RankedPlays({required this.name, required this.plays, this.share});

  /// What it is called.
  final String name;

  /// How many plays it accounts for.
  final int plays;

  /// The fraction of every play its ranking counted — the whole ranking, not
  /// the lines kept for display — or `null` where nobody worked it out.
  final double? share;
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
  /// Counted so the screen can say *why* its totals stand above rankings that
  /// do not add up to them: these files are counted in the one and appear in
  /// none of the others.
  ///
  /// A count of files rather than of their plays, which is the honest shape
  /// for it — "three of your tracks are untagged" is something an owner can go
  /// and act on, where a number of plays is only the size of the hole. It is
  /// therefore not the arithmetic difference between the totals and the
  /// rankings, and the sentence on screen does not claim it is.
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
/// 4. **A track is a file.** Counted by its path and only *labelled* by its
///    title: five records that each open with an "Intro" are five tracks, not
///    one that was played five times as often as anything else.
MusicStats musicStatsFrom({
  required PlayHistory history,
  required MusicCatalog catalog,
  int limit = rankingLength,
}) {
  if (history.isEmpty) return MusicStats.empty;

  final tracks = <String, int>{};
  final trackNames = <String, String>{};
  final artists = <String, int>{};
  // Keyed by the record rather than by its title, for the reason `albumsIn`
  // groups by the pair: two artists can name a record the same thing, and one
  // line adding their plays together is a chart that says an owner played
  // something they never played.
  final albums = <(String album, String? artist), int>{};
  final genres = <String, int>{};
  var untagged = 0;

  for (final played in history.tracks.values) {
    final entry = catalog.entryAt(played.path);
    final plays = played.plays;

    // Counted by its path, and named by its title or by the file when the
    // tags carry none — see rules 3 and 4.
    tracks.update(played.path, (e) => e + plays, ifAbsent: () => plays);
    trackNames[played.path] = entry?.title ?? _fileNameOf(played.path);

    final artist = entry?.albumArtist;
    final album = entry?.album;
    // Through the same trimming rule every other tag in the application
    // reads by, so a genre of three spaces is absent here too. A set, so a
    // track is credited once to a genre it somehow lists twice.
    final entryGenres = <String>{
      for (final raw in entry?.genres ?? const <String>[]) ?trimmedOrNull(raw),
    };

    // Only a file the catalog holds can be said to lack tags. One it no
    // longer holds — moved, deleted, or a library that would not load — has
    // nothing to correct, and counting it would send an owner looking for
    // tags on files that are not there.
    if (entry != null &&
        artist == null &&
        album == null &&
        entryGenres.isEmpty) {
      untagged++;
    }

    if (artist != null) {
      artists.update(artist, (e) => e + plays, ifAbsent: () => plays);
    }
    if (album != null) {
      albums.update((album, artist), (e) => e + plays, ifAbsent: () => plays);
    }
    for (final genre in entryGenres) {
      genres.update(genre, (e) => e + plays, ifAbsent: () => plays);
    }
  }

  return MusicStats(
    totalPlays: history.totalPlays,
    distinctTracks: history.distinctTracks,
    tracks: _rankedBy(tracks, limit, (path) => trackNames[path]!),
    artists: _ranked(artists, limit),
    albums: _rankedBy(albums, limit, (record) => record.$1),
    genres: _ranked(genres, limit),
    untaggedTracks: untagged,
  );
}

/// [counts] as the top [limit] lines, most played first, where the key is
/// already the name.
List<RankedPlays> _ranked(Map<String, int> counts, int limit) =>
    _rankedBy(counts, limit, (name) => name);

/// [counts] as the top [limit] lines, most played first, named by [nameOf].
///
/// The key and the name are separate so that a ranking can be counted by
/// something finer than it is labelled with — the albums are, because a record
/// is its title *and* its artist while the line only has room for the title.
///
/// Ties break by name, so a ranking is the same list every time it is read
/// rather than one whose equal rows swap places between openings. Through
/// [byName], which is the case-insensitive comparison the listings order by:
/// ranking `Blue` above `abbey road` because capitals sort first is the kind of
/// order nobody reading a chart is expecting.
List<RankedPlays> _rankedBy<K>(
  Map<K, int> counts,
  int limit,
  String Function(K key) nameOf,
) {
  // The whole ranking's plays, before it is cut to [limit]: a share of the
  // top ten alone is a share of the ten, and overstates the leader by however
  // much the rest of the library was played.
  final total = counts.values.fold<int>(0, (sum, plays) => sum + plays);

  final lines = [
    for (final entry in counts.entries)
      RankedPlays(
        name: nameOf(entry.key),
        plays: entry.value,
        share: total == 0 ? 0 : entry.value / total,
      ),
  ]..sort((a, b) {
    final byPlays = b.plays.compareTo(a.plays);

    return byPlays != 0 ? byPlays : byName(a.name, b.name);
  });

  return lines.length <= limit ? lines : lines.sublist(0, limit);
}

/// The name on disk, for the one ranking that falls back to it.
String _fileNameOf(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));

  return cut < 0 ? path : path.substring(cut + 1);
}
