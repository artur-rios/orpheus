import 'audio_file.dart';
import 'music_entry.dart';

/// One artist, or one album, and the tracks under it.
///
/// [name] is `null` for the group of files whose tags name none. A null name
/// rather than a translated "Unknown artist" string, because this is the
/// domain: what the catalog knows is that the tag is absent, and what to call
/// that is the presentation's decision and the translator's.
class MusicGroup {
  /// Creates a group.
  const MusicGroup({required this.name, required this.entries});

  /// What the group is called, or `null` when its files name nothing.
  final String? name;

  /// The tracks in it.
  final List<MusicEntry> entries;

  /// Whether this is the group of files that carry no tag.
  bool get isUntagged => name == null;

  /// How long the whole group runs, or `null` where any track's length is
  /// unknown — a total that quietly omitted the tracks it could not measure
  /// would be a number the owner has no way to read.
  Duration? get duration {
    var total = Duration.zero;
    for (final entry in entries) {
      final length = entry.duration;
      if (length == null) return null;
      total += length;
    }

    return total;
  }
}

/// Every artist in [library], alphabetically, with the untagged files last.
///
/// The album artist, not the track's performer: the list answers "whose
/// records are these", and a record with guests on it belongs to the artist
/// who made it rather than to everyone who played on it. A file with no
/// album-artist tag falls back to its performer, so a library tagged the old
/// way lists exactly as it did.
List<MusicGroup> artistsIn(List<MusicEntry> library) =>
    _groupedBy(library, (entry) => entry.albumArtist);

/// Every album in [library], alphabetically, with the untagged files last.
///
/// Keyed by album *and* album artist: two different artists can name a record
/// the same thing, and merging them would show one artist's tracks inside
/// another's album — the same rule [albumOf] applies when it builds a queue.
///
/// The album artist is also where a compilation stops fragmenting: keyed by
/// the performer, twelve performers on one record are twelve albums of one
/// track; keyed by the record's own artist they are one album again.
List<MusicGroup> albumsIn(List<MusicEntry> library) {
  final byKey = <(String?, String?), List<MusicEntry>>{};
  for (final entry in library) {
    byKey.putIfAbsent((entry.album, entry.albumArtist), () => []).add(entry);
  }

  final groups = [
    for (final key in byKey.keys)
      MusicGroup(name: key.$1, entries: inTrackOrder(byKey[key]!)),
  ];

  // Artist as the tiebreak: two albums can share a title under different
  // artists — this keys by `(album, albumArtist)` precisely so they stay two
  // groups — and with no tiebreak their relative order was whichever the map
  // happened to iterate them in, which is insertion order and not anything an
  // owner could predict or rely on.
  return _sortedByName(
    groups,
    tiebreak: (group) => group.entries.first.albumArtist,
  );
}

/// [artist]'s albums, alphabetically, where [artist] is an album artist.
///
/// `null` selects the files that name no artist, which is what drilling into
/// the untagged group does.
List<MusicGroup> albumsOfArtist(String? artist, List<MusicEntry> library) =>
    albumsIn([
      for (final entry in library)
        if (entry.albumArtist == artist) entry,
    ]);

/// The tracks of [artist]'s [album], in track order, where [artist] is the
/// album's artist — which is what the album row drilled in with.
List<MusicEntry> tracksOfAlbum(
  String? album,
  String? artist,
  List<MusicEntry> library,
) => inTrackOrder([
  for (final entry in library)
    if (entry.album == album && entry.albumArtist == artist) entry,
]);

/// Every track in [library], by title, with the untitled ones last.
List<MusicEntry> songsIn(List<MusicEntry> library) =>
    [...library]..sort((a, b) => byName(a.title, b.title));

/// The tracks of [entry]'s album, in track order.
///
/// A file whose album the tags do not name is its own album of one: two
/// untitled files are not the same record, and treating a blank field as a
/// grouping key would queue an owner's whole collection of loose tracks
/// together.
///
/// Keyed by the album's artist rather than the track's, as [albumsIn] is: a
/// queue built from a group has to contain what the group showed, and keying
/// this on the performer would mean pressing play on a compilation queued only
/// the tracks whose performer matched the one started from.
List<AudioFile> albumOf(MusicEntry entry, List<MusicEntry> library) {
  final album = entry.album;
  if (album == null) return [entry.file];

  final artist = entry.albumArtist;

  return [
    for (final candidate in inTrackOrder([
      for (final candidate in library)
        // Two different artists can name an album the same thing, so the album
        // is the pair. Exact equality including the absent case: an album
        // whose artist no tag names is its own record, and a permissive `null`
        // arm here would queue every album of that title under a group that
        // listed only the untagged files.
        if (candidate.album == album && candidate.albumArtist == artist)
          candidate,
    ]))
      candidate.file,
  ];
}

/// Every track by [entry]'s album artist, album by album.
///
/// The album artist, so that what an artist queue plays is what the Artists
/// list showed under that name — including the guest tracks on their records.
List<AudioFile> artistOf(MusicEntry entry, List<MusicEntry> library) {
  final artist = entry.albumArtist;
  if (artist == null) return [entry.file];

  return inArtistOrder([
    for (final candidate in library)
      if (candidate.albumArtist == artist) candidate,
  ]);
}

/// [entries], grouped by album and ordered within each album.
///
/// [artistOf] performs the same album-then-track ordering, but it starts from a
/// single seed track and a whole library to filter down from, and it
/// deliberately answers just that one file when the seed names no artist. That
/// early return is wrong here: [entries] may already be the untagged-artist
/// group, and every track in it belongs in the result rather than only the
/// first — so this sorts the list it is given rather than re-deriving one from
/// a single file.
List<AudioFile> inArtistOrder(List<MusicEntry> entries) {
  final ordered = [...entries]..sort((a, b) {
    final byAlbum = (a.album ?? '').compareTo(b.album ?? '');
    if (byAlbum != 0) return byAlbum;

    return _trackComparison(a, b);
  });

  return [for (final entry in ordered) entry.file];
}

/// [entries] in the order the record is listened to: disc, then track number,
/// then title.
///
/// A track with no number sorts after the numbered ones rather than at the
/// front, which is where a missing number would otherwise put it.
List<MusicEntry> inTrackOrder(List<MusicEntry> entries) =>
    [...entries]..sort(_trackComparison);

/// Case-insensitively by name, with an absent name last.
///
/// Absent last rather than first: the untagged files are a chore to work
/// through, not the first thing an owner came to see.
int byName(String? left, String? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;

  return left.toLowerCase().compareTo(right.toLowerCase());
}

/// [entries] again, each told who the record it belongs to is by.
///
/// Read once when the library is built, because the answer is a property of the
/// *record* and no single file holds it: a track carrying no album-artist tag
/// cannot say whose album it is on, and the tracks beside it can.
///
/// Two ways a record answers, in order:
///
/// 1. **A tag on any of its tracks.** Files are half-tagged all the time — one
///    editor writes the frame, another does not, and several common tag
///    formats have no field for it at all — and one track saying `50 Cent`
///    settles the record for the ones that say nothing.
/// 2. **Its most common performer.** With no tag anywhere, the artist most of
///    the record's tracks name is whose record it is; the others are guests on
///    it.
///
/// A record with no name of its own is left alone: two untitled files are not
/// the same record, and grouping on a blank field would make one record of an
/// owner's every loose track.
///
/// The second rule is a judgement, and worth naming as one: a genuine
/// various-artists compilation with no album artist anywhere lands under
/// whichever performer has the most tracks on it. That is a worse answer for
/// that one record than listing all of them — and a far better one for every
/// ordinary album with a guest on it, which is what most libraries are made
/// of. An owner who disagrees has the tag, and it wins.
List<MusicEntry> albumArtistsAcross(List<MusicEntry> entries) {
  final tagged = <String, Map<String, int>>{};
  final performers = <String, Map<String, int>>{};

  for (final entry in entries) {
    final album = entry.album;
    if (album == null) continue;

    if (trimmedOrNull(entry.metadata.albumArtist) case final artist?) {
      _count(tagged, album, artist);
    }
    if (entry.artist case final artist?) {
      _count(performers, album, artist);
    }
  }

  return [
    for (final entry in entries)
      entry.withRecordArtist(
        entry.album == null
            ? null
            : _commonest(tagged[entry.album!]) ??
                  _commonest(performers[entry.album!]),
      ),
  ];
}

void _count(Map<String, Map<String, int>> into, String album, String artist) =>
    into
        .putIfAbsent(album, () => {})
        .update(artist, (count) => count + 1, ifAbsent: () => 1);

/// The name most of them carry, or `null` when there are none.
///
/// Ties break alphabetically rather than by encounter order: a library listing
/// its artists differently depending on which file the scan happened to read
/// first would be a library that reorders itself for no reason the owner can
/// see.
String? _commonest(Map<String, int>? counts) {
  if (counts == null || counts.isEmpty) return null;

  final names = counts.keys.toList()..sort();

  return names.reduce(
    (best, name) => counts[name]! > counts[best]! ? name : best,
  );
}

List<MusicGroup> _groupedBy(
  List<MusicEntry> library,
  String? Function(MusicEntry entry) key,
) {
  final byName = <String?, List<MusicEntry>>{};
  for (final entry in library) {
    byName.putIfAbsent(key(entry), () => []).add(entry);
  }

  return _sortedByName([
    for (final name in byName.keys)
      MusicGroup(name: name, entries: inTrackOrder(byName[name]!)),
  ]);
}

/// [groups], sorted by name and, on a tie, by [tiebreak].
List<MusicGroup> _sortedByName(
  List<MusicGroup> groups, {
  String? Function(MusicGroup group)? tiebreak,
}) => [...groups]
  ..sort((a, b) {
    final byNameResult = byName(a.name, b.name);
    if (byNameResult != 0 || tiebreak == null) return byNameResult;

    return byName(tiebreak(a), tiebreak(b));
  });

/// Disc, then track number, then title — the order a record is listened to.
int _trackComparison(MusicEntry a, MusicEntry b) {
  final leftDisc = a.metadata.disc;
  final rightDisc = b.metadata.disc;
  if (leftDisc != null && rightDisc != null && leftDisc != rightDisc) {
    return leftDisc.compareTo(rightDisc);
  }

  final left = a.metadata.track;
  final right = b.metadata.track;

  if (left != null && right != null && left != right) {
    return left.compareTo(right);
  }
  if (left != null && right == null) return -1;
  if (left == null && right != null) return 1;

  return byName(a.title, b.title);
}
