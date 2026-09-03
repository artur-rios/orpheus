import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../domain/audio_file.dart';
import '../domain/catalog_store.dart';
import '../domain/music_catalog.dart';
import '../domain/music_entry.dart';
import '../domain/music_grouping.dart';
import '../domain/track_metadata.dart';

/// [CatalogStore] as one JSON document.
///
/// One document rather than a row store, because the whole library is read at
/// once and never queried piecemeal: every screen in the music area groups
/// across all of it, so there is no query a database would answer that reading
/// the file does not.
///
/// Written to a temporary file and renamed over the real one. A catalog
/// half-written because the application was closed mid-scan is a catalog that
/// will not parse, and the owner would lose the whole library to it; a rename
/// is atomic on every filesystem this runs on.
class JsonCatalogStore implements CatalogStore {
  /// Creates a store writing into [directory].
  JsonCatalogStore(this.directory);

  static final Logger _log = Logger('library');

  /// The document's version, written into it and checked on read.
  ///
  /// A catalog written by a version that recorded different fields is
  /// discarded rather than half-read: it costs one re-scan, and the
  /// alternative is a library that is subtly wrong in ways nobody can see.
  static const int documentVersion = 1;

  /// The file's name inside [directory].
  static const String fileName = 'catalog.json';

  /// Where the document is kept.
  final String directory;

  /// The document's path.
  String get path => p.join(directory, fileName);

  @override
  Future<MusicCatalog> read() async {
    final file = File(path);
    if (!file.existsSync()) return MusicCatalog.empty;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return MusicCatalog.empty;
      if (decoded['version'] != documentVersion) {
        _log.info('the catalog was written by another version; re-scanning');
        return MusicCatalog.empty;
      }

      final scannedAt = decoded['scannedAt'];
      final tracks = decoded['tracks'];
      if (tracks is! List) return MusicCatalog.empty;

      return MusicCatalog(
        // Re-derived on read rather than stored: it is a conclusion about the
        // library as a whole, and one stored alongside the tracks would be a
        // second copy of a fact the tracks already contain.
        entries: albumArtistsAcross([
          for (final track in tracks)
            if (track is Map<String, dynamic>) _entryFrom(track),
        ]),
        scannedAt: scannedAt is String ? DateTime.tryParse(scannedAt) : null,
      );
    } on Object catch (error, trace) {
      // Broad by intent, as everywhere a stored document is read: a catalog
      // nobody can decode is a catalog nobody has, and the answer to that is
      // an empty library and a re-scan, not a launch that fails.
      _log.warning('the catalog could not be read; re-scanning', error, trace);
      return MusicCatalog.empty;
    }
  }

  @override
  Future<void> write(MusicCatalog catalog) async {
    await Directory(directory).create(recursive: true);

    final temporary = File('$path.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': documentVersion,
        'scannedAt': (catalog.scannedAt ?? DateTime.now()).toIso8601String(),
        'tracks': [for (final entry in catalog.entries) _rowOf(entry)],
      }),
      flush: true,
    );
    await temporary.rename(path);
  }

  @override
  Future<void> clear() async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  static Map<String, Object?> _rowOf(MusicEntry entry) {
    final metadata = entry.metadata;

    return {
      'path': entry.file.path,
      'size': entry.file.sizeInBytes,
      'modified': entry.file.modifiedAt.millisecondsSinceEpoch,
      if (metadata.title != null) 'title': metadata.title,
      if (metadata.artist != null) 'artist': metadata.artist,
      if (metadata.albumArtist != null) 'albumArtist': metadata.albumArtist,
      if (metadata.album != null) 'album': metadata.album,
      if (metadata.genre != null) 'genre': metadata.genre,
      if (metadata.track != null) 'track': metadata.track,
      if (metadata.trackTotal != null) 'trackTotal': metadata.trackTotal,
      if (metadata.disc != null) 'disc': metadata.disc,
      if (metadata.year != null) 'year': metadata.year,
      if (metadata.duration != null) 'durationMs': metadata.duration!.inMilliseconds,
      if (metadata.coverId != null) 'coverId': metadata.coverId,
    };
  }

  static MusicEntry _entryFrom(Map<String, dynamic> row) {
    final durationMs = row['durationMs'];

    return MusicEntry(
      file: AudioFile(
        path: row['path'] as String,
        sizeInBytes: row['size'] as int? ?? 0,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          row['modified'] as int? ?? 0,
        ),
      ),
      metadata: TrackMetadata(
        title: row['title'] as String?,
        artist: row['artist'] as String?,
        albumArtist: row['albumArtist'] as String?,
        album: row['album'] as String?,
        genre: row['genre'] as String?,
        track: row['track'] as int?,
        trackTotal: row['trackTotal'] as int?,
        disc: row['disc'] as int?,
        year: row['year'] as int?,
        duration: durationMs is int
            ? Duration(milliseconds: durationMs)
            : null,
        coverId: row['coverId'] as String?,
      ),
    );
  }
}
