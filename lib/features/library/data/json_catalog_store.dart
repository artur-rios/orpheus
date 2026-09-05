import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
      // On an isolate for the same reason the scan is: decoding this document
      // is several megabytes of JSON and one object per track, all of it
      // synchronous, and on the interface's isolate it is a held frame at the
      // exact moment the first screen is being drawn. Only the path crosses
      // going in, and the entries — plain objects — coming back.
      final document = await Isolate.run(() => _parse(path));

      if (document.note case final note?) _log.info(note);

      return MusicCatalog(
        entries: document.entries ?? const [],
        scannedAt: document.scannedAt,
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

    // Encoded on an isolate, and written from there too: the encode is the
    // expensive half and the write is what must not be interleaved with it.
    // The entries go across as plain objects, which costs a fraction of what
    // encoding them costs.
    final entries = catalog.entries;
    final scannedAt = catalog.scannedAt ?? DateTime.now();
    final destination = path;

    await Isolate.run(() => _writeDocument(destination, entries, scannedAt));
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

/// What [_parse] found in the document, or why it found nothing.
///
/// A plain object because it crosses an isolate boundary. The [note] carries
/// the one thing the parse knows and the caller cannot work out for itself —
/// that the document was written by another version — so that it is logged on
/// the isolate that has the logger rather than on the one that has the file.
class _CatalogDocument {
  const _CatalogDocument({this.entries, this.scannedAt, this.note});

  /// Every track the document holds, or `null` when it holds none.
  final List<MusicEntry>? entries;

  /// When the scan that wrote it ran.
  final DateTime? scannedAt;

  /// What is worth saying about a document that yielded nothing.
  final String? note;
}

/// Reads and decodes the document at [path].
///
/// Runs on an isolate of its own — see [JsonCatalogStore.read]. It throws
/// rather than reporting a failure, and the caller turns that into an empty
/// library: an isolate that dies takes its error back across the boundary.
_CatalogDocument _parse(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) return const _CatalogDocument();
  if (decoded['version'] != JsonCatalogStore.documentVersion) {
    return const _CatalogDocument(
      note: 'the catalog was written by another version; re-scanning',
    );
  }

  final scannedAt = decoded['scannedAt'];
  final tracks = decoded['tracks'];
  if (tracks is! List) return const _CatalogDocument();

  return _CatalogDocument(
    // Re-derived on read rather than stored: it is a conclusion about the
    // library as a whole, and one stored alongside the tracks would be a
    // second copy of a fact the tracks already contain. Derived here, on the
    // isolate, because it is a pass over every track and there is no reason
    // for the interface to wait through it.
    entries: albumArtistsAcross([
      for (final track in tracks)
        if (track is Map<String, dynamic>) JsonCatalogStore._entryFrom(track),
    ]),
    scannedAt: scannedAt is String ? DateTime.tryParse(scannedAt) : null,
  );
}

/// Encodes [entries] and puts the document at [path].
///
/// Written to a temporary file and renamed over the real one — see
/// [JsonCatalogStore]. Runs on an isolate of its own.
void _writeDocument(
  String path,
  List<MusicEntry> entries,
  DateTime scannedAt,
) {
  final temporary = File('$path.tmp')
    ..writeAsStringSync(
      jsonEncode({
        'version': JsonCatalogStore.documentVersion,
        'scannedAt': scannedAt.toIso8601String(),
        'tracks': [for (final entry in entries) JsonCatalogStore._rowOf(entry)],
      }),
      flush: true,
    );

  temporary.renameSync(path);
}
