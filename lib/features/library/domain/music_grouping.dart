import 'audio_file.dart';
import 'genres.dart';
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

  /// How long the whole group runs, or `null` where any track's length is
  /// unknown — a total that quietly omitted the tracks it could not measure
  /// would be a number the owner has no way to read.
  Duration? get duration => _totalDuration(entries);
}

/// One genre, and the tracks that carry it.
///
/// [key] and [name] are `null` for the group of tracks that carry no genre, for
/// the reason [MusicGroup.name] is: the domain knows the tag is absent, and what
/// to call that is the presentation's decision. [key] is what matches
/// ([genreKey]); [name] is what is shown, the spelling the library uses most.
class GenreGroup {
  /// Creates a group.
  const GenreGroup({
    required this.key,
    required this.name,
    required this.tracks,
  });

  /// What tracks are matched to the genre by, or `null` for *No genre*.
  final String? key;

  /// What the genre is called, or `null` for *No genre*.
  final String? name;

  /// The tracks that carry it, as [tracksOfGenre] orders them.
  final List<MusicEntry> tracks;

  /// How long the whole genre runs, by the rule [MusicGroup.duration] states.
  Duration? get duration => _totalDuration(tracks);
}

/// The total of [entries]' lengths, or `null` where any one is unknown — a total
/// that quietly omitted the tracks it could not measure would be a number the
/// owner has no way to read.
Duration? _totalDuration(Iterable<MusicEntry> entries) {
  var total = Duration.zero;
  for (final entry in entries) {
    final length = entry.duration;
    if (length == null) return null;
    total += length;
  }

  return total;
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
  // owner could predict or rely on. The whole rule lives in [_albumOrder],
  // because [inArtistOrder] has to queue an artist's records in exactly the
  // order this lists them.
  return [...groups]
    ..sort((a, b) => _albumOrder(a.entries.first, b.entries.first));
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
/// Keyed by the album's artist rather than the track's, as [albumsIn] is: a
/// queue built from a group has to contain what the group showed, and keying
/// this on the performer would mean pressing play on a compilation queued only
/// the tracks whose performer matched the one started from.
///
/// A file whose album the tags do not name belongs to the untitled group —
/// every file under the same album artist that names no record either — and it
/// queues that whole group, because that is the group the Albums list showed
/// and drilled into. An earlier version answered with the seed file alone,
/// which made pressing play on a group of forty tracks play one of them.
///
/// The caller decides what a file the library does not hold at all means; this
/// is a question about a library and an entry in it.
List<AudioFile> albumOf(MusicEntry entry, List<MusicEntry> library) {
  final album = entry.album;
  final artist = entry.albumArtist;

  return [
    for (final candidate in inTrackOrder([
      for (final candidate in library)
        // Two different artists can name an album the same thing, so the album
        // is the pair. Exact equality including the absent case on both sides,
        // which is what makes the untitled group of one artist a different
        // record from the untitled group of another.
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
///
/// A file whose artist the tags do not name queues the untagged group, for the
/// reason [albumOf] queues the untitled one: it is the group the Artists list
/// showed, and a play button on a group of forty that played one of them was
/// answering a different question from the one it was asked.
List<AudioFile> artistOf(MusicEntry entry, List<MusicEntry> library) {
  final artist = entry.albumArtist;

  return inArtistOrder([
    for (final candidate in library)
      if (candidate.albumArtist == artist) candidate,
  ]);
}

/// [entries], grouped by album and ordered within each album.
///
/// [artistOf] performs the same album-then-track ordering, but it starts from a
/// single seed track and a whole library to filter down from; this sorts the
/// list it is given, which is what the callers that already hold a group need.
///
/// The albums come in the order the artist's screen lists them — the rule is
/// [_albumOrder], shared with [albumsIn] — so pressing play on an artist plays
/// the records top to bottom as the owner sees them. An earlier version sorted
/// case-sensitively with the untitled group first, which played `abbey road`
/// after `Zooropa` and the loose tracks the screen lists last ahead of
/// everything.
List<AudioFile> inArtistOrder(List<MusicEntry> entries) => [
  for (final entry in _artistOrdered(entries)) entry.file,
];

/// Every entry whose album artist is [artist], album by album as
/// [inArtistOrder] orders them.
///
/// The entries themselves rather than their files, for the caller that has to
/// read what they say — the tag editor opens a form over them. `null` selects
/// the untagged group, as [albumsOfArtist] does.
List<MusicEntry> entriesOfArtist(String? artist, List<MusicEntry> library) =>
    _artistOrdered([
      for (final entry in library)
        if (entry.albumArtist == artist) entry,
    ]);

/// [entries] in the order an artist's records are listened to.
List<MusicEntry> _artistOrdered(List<MusicEntry> entries) =>
    [...entries]..sort(_recordThenTrackOrder);

/// Whether [entry] carries the genre [key] names.
///
/// `null` is *No genre*, which is the tracks that carry none, exactly as a
/// `null` artist selects the untagged artist. Otherwise a track matches when any
/// of its genres has that [genreKey], so a track tagged `Rock` and `Pop` is
/// under both.
bool hasGenre(MusicEntry entry, String? key) => key == null
    ? entry.genres.isEmpty
    : entry.genres.any((genre) => genreKey(genre) == key);

/// What each genre in [library] is called, by [genreKey].
///
/// The spelling most tracks use, trimmed: a library that tags `Rock` on two
/// tracks and `rock` on one shows *Rock*, not whichever the scan met first. A
/// track counts once for a genre however many spellings it holds, since a
/// hand-built entry can hold `Rock` and `rock` together. A tie goes to the
/// spelling that sorts first by [byName], then by plain `compareTo`, so the name
/// never depends on the order the files happened to be read in.
Map<String, String> genreNamesIn(List<MusicEntry> library) =>
    _genresAcross(library).names;

/// What each genre in [library] is called, and the tracks that carry it, in one
/// pass over the library.
///
/// One pass because the Genres list is built from it on every rebuild, over the
/// whole library: asking each genre for its tracks in turn walked every track
/// once per genre, which at forty thousand tracks and four hundred genres was
/// most of a second on the interface's isolate. Each track's genre keys are
/// worked out once here, and it is appended to the bucket of each — once per
/// genre, however many spellings of it the track holds, as [hasGenre] matches.
///
/// The buckets are in the library's own order, unsorted; [genresIn] orders
/// them. A track whose only genres are blank is in none, and `null` holds the
/// tracks with no genres at all — both exactly as [hasGenre] decides.
({Map<String, String> names, Map<String?, List<MusicEntry>> tracks})
_genresAcross(List<MusicEntry> library) {
  final spellings = <String, Map<String, int>>{};
  final tracks = <String?, List<MusicEntry>>{};
  for (final entry in library) {
    if (entry.genres.isEmpty) {
      (tracks[null] ??= []).add(entry);
      continue;
    }

    final seen = <String>{};
    for (final genre in entry.genres) {
      final name = genre.trim();
      final key = genreKey(name);
      if (key.isEmpty || !seen.add(key)) continue;

      _count(spellings, key, name);
      (tracks[key] ??= []).add(entry);
    }
  }

  return (
    names: {
      for (final MapEntry(:key, value: counts) in spellings.entries)
        key: _commonSpelling(counts),
    },
    tracks: tracks,
  );
}

/// The spelling in [counts] that most tracks use, ties broken as
/// [genreNamesIn] states.
String _commonSpelling(Map<String, int> counts) {
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;

      final alphabetical = byName(a.key, b.key);
      return alphabetical != 0 ? alphabetical : a.key.compareTo(b.key);
    });

  return ranked.first.key;
}

/// Every genre in [library], alphabetically, with *No genre* last.
///
/// *No genre* is there only when some track carries none, so a fully tagged
/// library does not list a group with nothing in it. A track with several
/// genres is in the group of each.
List<GenreGroup> genresIn(List<MusicEntry> library) {
  final (:names, :tracks) = _genresAcross(library);
  final named = names.entries.toList()
    ..sort((a, b) => byName(a.value, b.value));

  return [
    for (final MapEntry(:key, :value) in named)
      GenreGroup(
        key: key,
        name: value,
        tracks: tracks[key]!..sort(_genreTrackOrder),
      ),
    if (tracks[null] case final untagged?)
      GenreGroup(
        key: null,
        name: null,
        tracks: untagged..sort(_genreTrackOrder),
      ),
  ];
}

/// The tracks in [library] that carry the genre [key] names, by artist, then
/// record, then track.
///
/// Playing a genre is by track — only what is tagged with it — in the order an
/// artist's queue plays ([inArtistOrder] shares the record-then-track rule), one
/// artist after another by their name. Browsing is another question; see
/// [genreLibrary].
List<MusicEntry> tracksOfGenre(String? key, List<MusicEntry> library) => [
  for (final entry in library)
    if (hasGenre(entry, key)) entry,
]..sort(_genreTrackOrder);

/// The order [tracksOfGenre] gives, and [genresIn] gives each of its groups:
/// by artist, then record, then track.
int _genreTrackOrder(MusicEntry a, MusicEntry b) {
  final byArtist = byName(a.albumArtist, b.albumArtist);
  if (byArtist != 0) return byArtist;

  // Two artists whose names differ only in case are two artists; without this
  // their records would interleave.
  final exactArtist = (a.albumArtist ?? '').compareTo(b.albumArtist ?? '');
  if (exactArtist != 0) return exactArtist;

  return _recordThenTrackOrder(a, b);
}

/// The entries of [library] that browsing the genre [key] names shows, in the
/// library's own order.
///
/// Browsing is by record: a record with one track of the genre is listed under
/// it and opened whole, every track on it, because the owner is looking for the
/// record. A record is `(album, albumArtist)`, as [albumsIn] keys it.
///
/// A record with no name of its own is not a record: the artist's loose tracks
/// are not one album, and opening all of them because one is tagged would show
/// the owner tracks that have nothing to do with the genre. Only its tracks that
/// carry the genre are in.
List<MusicEntry> genreLibrary(String? key, List<MusicEntry> library) {
  final records = <(String?, String?)>{
    for (final entry in library)
      if (entry.album != null && hasGenre(entry, key))
        (entry.album, entry.albumArtist),
  };

  return [
    for (final entry in library)
      if (entry.album == null
          ? hasGenre(entry, key)
          : records.contains((entry.album, entry.albumArtist)))
        entry,
  ];
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
///
/// **What identifies a record here is its title and its folder**, not its title
/// alone — see [_RecordKey]. Every grouping downstream keys albums by
/// `(album, albumArtist)` precisely so that two artists who name a record the
/// same thing stay two records; a derivation that pooled them by title would
/// hand both of them one artist and defeat that key before it was ever read.
List<MusicEntry> albumArtistsAcross(List<MusicEntry> entries) {
  final tagged = <_RecordKey, Map<String, int>>{};
  final performers = <_RecordKey, Map<String, int>>{};

  // The same two counts pooled across every folder that shares an album title.
  // Read only to break a tie one folder cannot break for itself — see
  // [_commonest] — which is what keeps a record split into `CD1` and `CD2` one
  // record when a disc of it is half guests.
  final taggedByTitle = <String, Map<String, int>>{};
  final performersByTitle = <String, Map<String, int>>{};

  for (final entry in entries) {
    final record = _recordOf(entry);
    if (record == null) continue;

    if (trimmedOrNull(entry.metadata.albumArtist) case final artist?) {
      _count(tagged, record, artist);
      _count(taggedByTitle, record.album, artist);
    }
    if (entry.artist case final artist?) {
      _count(performers, record, artist);
      _count(performersByTitle, record.album, artist);
    }
  }

  return [
    for (final entry in entries)
      entry.withRecordArtist(switch (_recordOf(entry)) {
        null => null,
        final record =>
          _commonest(
            tagged[record],
            breakTiesWith: taggedByTitle[record.album],
          ) ??
              _commonest(
                performers[record],
                breakTiesWith: performersByTitle[record.album],
              ),
      }),
  ];
}

/// What tells one record from another while its artist is still being worked
/// out.
///
/// The album title and the folder the file sits in. The folder is what
/// separates two artists who named a record the same thing, and it is the right
/// separator rather than a convenient one: a record is a directory of tracks
/// on every machine this runs on, which is also why the sidecar cover is looked
/// for there.
///
/// What it does not separate is two same-titled records by different artists
/// loose in one flat folder — there is nothing left to tell those apart before
/// the artist is known, and the album-artist tag is what an owner has if they
/// care. A multi-disc set split into `CD1` and `CD2` is two keys rather than
/// one, which costs nothing: each half answers with the same artist, and
/// [albumsIn] keys by `(album, albumArtist)` and joins them again.
typedef _RecordKey = ({String album, String directory});

/// The record [entry] belongs to, or `null` when its tags name none.
_RecordKey? _recordOf(MusicEntry entry) {
  final album = entry.album;

  return album == null
      ? null
      : (album: album, directory: entry.file.directory);
}

void _count<K>(Map<K, Map<String, int>> into, K key, String artist) => into
    .putIfAbsent(key, () => {})
    .update(artist, (count) => count + 1, ifAbsent: () => 1);

/// The name most of them carry, or `null` when there are none.
///
/// [breakTiesWith] is the same tally taken over a wider set — every folder that
/// shares this album's title — and it is consulted only between names [counts]
/// ranks equally. A disc folder holding one track by the host and one by a
/// guest has no opinion of its own; the rest of the record does, and without
/// asking it the two halves of a multi-disc set could land under two different
/// artists and list as two records.
///
/// It can only reorder names already tied here, so a wider tally can never
/// overrule a folder that answered for itself — which is what keeps two
/// artists who named a record the same thing from being pooled into one.
///
/// What is left over breaks alphabetically rather than by encounter order: a
/// library listing its artists differently depending on which file the scan
/// happened to read first would be a library that reorders itself for no
/// reason the owner can see.
String? _commonest(Map<String, int>? counts, {Map<String, int>? breakTiesWith}) {
  if (counts == null || counts.isEmpty) return null;

  final names = counts.keys.toList()..sort();
  var best = names.first;

  for (final name in names.skip(1)) {
    final byCount = counts[name]!.compareTo(counts[best]!);
    if (byCount > 0) {
      best = name;
      continue;
    }
    if (byCount < 0) continue;

    final wider = (breakTiesWith?[name] ?? 0).compareTo(
      breakTiesWith?[best] ?? 0,
    );
    if (wider > 0) best = name;
  }

  return best;
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

/// [groups], sorted by name.
List<MusicGroup> _sortedByName(List<MusicGroup> groups) =>
    [...groups]..sort((a, b) => byName(a.name, b.name));

/// Where [a] sits relative to [b] within one artist: by record in the order the
/// artist's screen lists them, then by track.
int _recordThenTrackOrder(MusicEntry a, MusicEntry b) {
  final byAlbum = _albumOrder(a, b);
  if (byAlbum != 0) return byAlbum;

  return _trackComparison(a, b);
}

/// Where [a]'s record sits relative to [b]'s: by title as [byName] orders it,
/// then by album artist, then by the exact title.
///
/// The last step is what keeps two records whose titles differ only in case —
/// `Abc` and `abc`, which [albumsIn] keys as two — from comparing equal, which
/// would let a queue interleave their tracks by track number and list them in
/// whichever order the sort happened to leave them.
int _albumOrder(MusicEntry a, MusicEntry b) {
  final byTitle = byName(a.album, b.album);
  if (byTitle != 0) return byTitle;

  final byArtist = byName(a.albumArtist, b.albumArtist);
  if (byArtist != 0) return byArtist;

  return (a.album ?? '').compareTo(b.album ?? '');
}

/// Disc, then track number, then title — the order a record is listened to.
///
/// A track with no disc tag counts as disc 1. Most single-disc records carry
/// no disc tag at all, and on a set where only some tracks say, the silent
/// ones are far likelier to be the first disc than any other. Comparing discs
/// only when both sides named one — what this did before — was not an order at
/// all: an untagged track compared equal to both discs and fell through to the
/// track number, so it could sort ahead of disc 2's tracks against one
/// neighbour and behind them against another, and the record came back
/// interleaved.
int _trackComparison(MusicEntry a, MusicEntry b) {
  final byDisc = (a.metadata.disc ?? 1).compareTo(b.metadata.disc ?? 1);
  if (byDisc != 0) return byDisc;

  final left = a.metadata.track;
  final right = b.metadata.track;

  if (left != null && right != null && left != right) {
    return left.compareTo(right);
  }
  if (left != null && right == null) return -1;
  if (left == null && right != null) return 1;

  return byName(a.title, b.title);
}
