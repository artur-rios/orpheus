import 'package:path/path.dart' as p;

import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import 'autofill_field.dart';
import 'matching.dart';
import 'tag_writer.dart';

/// What a batch unit is looked up as.
enum BatchUnitKind {
  /// Songs of one album, looked up together as a release.
  record,

  /// One song that belongs to no record, looked up as a recording.
  track,
}

/// One thing a batch looks up: a record, or a lone track.
class BatchUnit {
  /// Creates a unit.
  const BatchUnit({
    required this.kind,
    required this.songs,
    required this.matchAgainst,
  });

  /// Whether this is a record or a lone track.
  final BatchUnitKind kind;

  /// The batch's writable songs of this unit, in disc and track order.
  ///
  /// The only songs a change is proposed for or written to.
  final List<MusicEntry> songs;

  /// Every song of the unit the search and the ranking should reckon with, in
  /// disc and track order: the library's, writable or not, and any batch song
  /// of it the library does not hold, so a batch built from a stale library
  /// still matches its own songs. Just the song itself for a lone track.
  final List<MusicEntry> matchAgainst;

  /// Whether the unit holds a writable song that the batch leaves out.
  ///
  /// A song nothing can be written to is not one: it is not going to be
  /// changed either way, so it does not make the batch a part of the record.
  bool get partial {
    final inBatch = {for (final song in songs) song.file.path};

    return matchAgainst.any(
      (song) =>
          canWriteTagsTo(song.file.path) && !inBatch.contains(song.file.path),
    );
  }

  /// Whether the unit holds any song, writable or not, that its writes leave
  /// out: one the batch does not hold, or one of a format no tag is written
  /// to.
  ///
  /// Writing an album or an album artist to the rest would part them from
  /// such a song, which the library groups by those two tags.
  bool get hasAlbumMatesOutside {
    final inBatch = {for (final song in songs) song.file.path};

    return matchAgainst.any((song) => !inBatch.contains(song.file.path));
  }

  /// A stable name for the unit: the normalised album artist and album of a
  /// record, `folder:` and the folder of a record of untitled songs, or
  /// `track:` and the path of a lone track.
  String get key {
    final first = songs.first;
    if (kind == BatchUnitKind.track) return 'track:${first.file.path}';
    if (first.album == null) return 'folder:${first.file.directory}';

    return _albumKey(first);
  }
}

/// A batch of songs split into what is looked up, and what cannot be.
class BatchPlan {
  /// Creates a plan.
  const BatchPlan({required this.units, required this.notWritable});

  /// The records, by normalised artist and then album, followed by the lone
  /// tracks, by path.
  final List<BatchUnit> units;

  /// The batch's songs [canWriteTagsTo] refuses, which are never looked up.
  final List<MusicEntry> notWritable;

  /// How many songs the batch holds, each counted once.
  int get songCount =>
      units.fold(0, (count, unit) => count + unit.songs.length) +
      notWritable.length;
}

/// [batch] split into records and lone tracks, as the design's section 4.1
/// says.
///
/// Songs are one record when they name the same album under the same album
/// artist, both normalised as [normalised] does. Songs that name no album are
/// one record when they share a folder with at least one more such song in
/// [library], and a lone track otherwise. A unit with no writable song in the
/// batch is dropped, and a song listed twice counts once.
BatchPlan planBatch(List<MusicEntry> batch, List<MusicEntry> library) {
  final byPath = <String, MusicEntry>{};
  for (final song in batch) {
    byPath.putIfAbsent(song.file.path, () => song);
  }

  final writable = <MusicEntry>[];
  final notWritable = <MusicEntry>[];
  for (final song in byPath.values) {
    (canWriteTagsTo(song.file.path) ? writable : notWritable).add(song);
  }

  // The library with any batch song it lacks added, so that a batch built from
  // a stale library still finds its own songs.
  final known = {for (final song in library) song.file.path: song};
  for (final song in byPath.values) {
    known.putIfAbsent(song.file.path, () => song);
  }

  final untitledPerFolder = <String, int>{};
  for (final song in known.values) {
    if (song.album != null) continue;
    untitledPerFolder.update(
      song.file.directory,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  String keyOf(MusicEntry song) {
    if (song.album != null) return _albumKey(song);
    if ((untitledPerFolder[song.file.directory] ?? 0) >= 2) {
      return 'folder:${song.file.directory}';
    }

    return 'track:${song.file.path}';
  }

  final inBatch = <String, List<MusicEntry>>{};
  for (final song in writable) {
    inBatch.putIfAbsent(keyOf(song), () => []).add(song);
  }

  final everySong = <String, List<MusicEntry>>{};
  for (final song in known.values) {
    final key = keyOf(song);
    if (!inBatch.containsKey(key)) continue;

    everySong.putIfAbsent(key, () => []).add(song);
  }

  final records = <BatchUnit>[];
  final tracks = <BatchUnit>[];
  for (final MapEntry(:key, value: songs) in inBatch.entries) {
    if (key.startsWith('track:')) {
      tracks.add(
        BatchUnit(kind: BatchUnitKind.track, songs: songs, matchAgainst: songs),
      );
      continue;
    }

    records.add(
      BatchUnit(
        kind: BatchUnitKind.record,
        songs: inTrackOrder(songs),
        matchAgainst: inTrackOrder(everySong[key]!),
      ),
    );
  }

  records.sort(_recordOrder);
  tracks.sort(
    (a, b) => a.songs.single.file.path.compareTo(b.songs.single.file.path),
  );

  return BatchPlan(units: [...records, ...tracks], notWritable: notWritable);
}

/// How long the lookup of [plan] takes, in whole minutes and at least one.
///
/// 2.5 seconds a unit, which is the one request a second MusicBrainz allows
/// and the few a unit needs, and a second more a unit where the cover is
/// chosen, for the second service it is fetched from.
int estimatedMinutes(BatchPlan plan, Set<AutofillField> fields) {
  final tenthsOfASecondEach = fields.contains(AutofillField.cover) ? 35 : 25;
  final tenths = plan.units.length * tenthsOfASecondEach;
  final minutes = (tenths + 599) ~/ 600;

  return minutes < 1 ? 1 : minutes;
}

/// What tells one record of named songs from another: the normalised album
/// artist and album.
///
/// Joined by a character [normalised] never leaves in, so no artist and album
/// can run into another pair.
String _albumKey(MusicEntry song) =>
    '${normalised(song.albumArtist ?? '')}|${normalised(song.album ?? '')}';

/// Where record [a] sits relative to [b]: by normalised artist, then album.
///
/// A record of untitled songs is ordered by its folder's name where an album
/// would be, as [releaseQueryFor] searches it by. The key breaks a remaining
/// tie, so the order never depends on the order the batch came in.
int _recordOrder(BatchUnit a, BatchUnit b) {
  final byArtist = _artistSort(a).compareTo(_artistSort(b));
  if (byArtist != 0) return byArtist;

  final byAlbum = _albumSort(a).compareTo(_albumSort(b));
  if (byAlbum != 0) return byAlbum;

  return a.key.compareTo(b.key);
}

String _artistSort(BatchUnit unit) =>
    normalised(unit.songs.first.albumArtist ?? '');

String _albumSort(BatchUnit unit) {
  final first = unit.songs.first;

  return normalised(first.album ?? p.basename(first.file.directory));
}
