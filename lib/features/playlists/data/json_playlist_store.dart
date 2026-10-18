import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../autofill/data/atomic_write.dart';
import '../domain/playlist.dart';
import '../domain/playlist_store.dart';

/// [PlaylistStore] as one JSON document, beside the catalog.
///
/// Unlike the catalog and the play history, this is the owner's own work and
/// cannot be built again, so it is handled with more care than they are:
/// - a write is atomic ([replaceFileAtomically]), so a crash or a full disk
///   leaves the previous document and never half of one;
/// - a document that cannot be understood is renamed to
///   `playlists.json.bad-<yyyyMMddTHHmmss>` rather than overwritten by the
///   next write, so what could not be understood — by this version, or
///   because it was damaged — is still there to be recovered by hand.
///
/// The document, `playlists.json`:
///
/// ```json
/// {
///   "version": 1,
///   "playlists": [
///     {
///       "id": "...",                 // generated, stable
///       "name": "Road trip",
///       "coverId": "...",            // or null: the mosaic
///       "createdAt": "2026-09-01T08:30:00.000Z",   // ISO-8601, UTC
///       "modifiedAt": "2026-10-02T17:45:12.000Z",
///       "entries": [
///         {
///           "id": "...",             // one per place in the playlist
///           "path": "/library/a.flac",
///           "title": "...",          // title, artist, album: or null
///           "artist": "...",
///           "album": "...",
///           "durationMs": 201250     // or null
///         }
///       ]
///     }
///   ]
/// }
/// ```
///
/// Any other version, or a document that does not have this shape in every
/// playlist and entry, is set aside whole: dropping the entries that look
/// wrong would be deleting a list the owner made without telling them.
class JsonPlaylistStore implements PlaylistStore {
  /// Creates a store writing into [directory].
  ///
  /// [clock] names the copy of an unreadable document and is a parameter so a
  /// test can pin it.
  JsonPlaylistStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final Logger _log = Logger('playlists');

  /// The document's version, written into it and checked on read.
  static const int documentVersion = 1;

  /// The file's name inside [directory].
  static const String fileName = 'playlists.json';

  /// Where the document is kept.
  final String directory;

  final DateTime Function() _clock;

  /// The document's path.
  String get path => p.join(directory, fileName);

  @override
  Future<List<Playlist>> read() async {
    final file = File(path);
    if (!file.existsSync()) return const [];

    // Only a document that was read and then not understood is set aside. A
    // file that cannot be opened — locked for a moment by an antivirus scan or
    // a sync client, say — is not a damaged one: its error goes up to the
    // caller, who can say so, rather than the playlists being set aside as if
    // they were lost. So the bytes are read and then decoded here, rather
    // than read as text: `readAsString` reports bytes that are not UTF-8 as a
    // [FileSystemException], the same as a file that could not be opened.
    try {
      final bytes = await file.readAsBytes();

      return _playlistsIn(jsonDecode(utf8.decode(bytes)));
    } on FormatException catch (error) {
      // Text that is not UTF-8, not JSON, or not the document's shape.
      await _setAside(file, error);

      return const [];
    }
  }

  @override
  Future<void> write(List<Playlist> all) async {
    await Directory(directory).create(recursive: true);

    final document = jsonEncode({
      'version': documentVersion,
      'playlists': [for (final playlist in all) _encode(playlist)],
    });

    replaceFileAtomically(path, Uint8List.fromList(utf8.encode(document)));
  }

  /// Renames the document that could not be understood to a name that keeps
  /// it.
  ///
  /// Throws when it cannot be renamed. Carrying on would return no playlists
  /// with the document still in place, and the next write would replace it:
  /// the one thing setting it aside is for preventing.
  Future<void> _setAside(File file, Object error) async {
    final aside = '$path.bad-${_stamp(_clock())}';
    try {
      await file.rename(aside);
    } on FileSystemException catch (renameError) {
      _log.severe(
        'the playlists could not be read, and could not be set aside',
        error,
      );
      throw FileSystemException(
        'Could not set the unreadable playlists aside: ${renameError.message}',
        path,
        renameError.osError,
      );
    }

    _log.severe(
      'the playlists could not be read; kept as ${p.basename(aside)}',
      error,
    );
  }

  static String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${at.year.toString().padLeft(4, '0')}${two(at.month)}'
        '${two(at.day)}T${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }

  static Map<String, Object?> _encode(Playlist playlist) => {
    'id': playlist.id,
    'name': playlist.name,
    'coverId': playlist.coverId,
    'createdAt': playlist.createdAt.toUtc().toIso8601String(),
    'modifiedAt': playlist.modifiedAt.toUtc().toIso8601String(),
    'entries': [
      for (final entry in playlist.entries)
        {
          'id': entry.id,
          'path': entry.path,
          'title': entry.title,
          'artist': entry.artist,
          'album': entry.album,
          'durationMs': entry.duration?.inMilliseconds,
        },
    ],
  };

  /// The playlists in a decoded document; throws a [FormatException] when it
  /// is not one this version understands.
  static List<Playlist> _playlistsIn(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the document is not an object');
    }
    if (decoded['version'] != documentVersion) {
      throw FormatException('unknown version ${decoded['version']}');
    }
    final playlists = decoded['playlists'];
    if (playlists is! List) {
      throw const FormatException('"playlists" is not a list');
    }

    return [for (final playlist in playlists) _decode(playlist)];
  }

  static Playlist _decode(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('a playlist is not an object');
    }
    final entries = json['entries'];
    if (entries is! List) {
      throw const FormatException('"entries" is not a list');
    }

    return Playlist(
      id: _text(json, 'id'),
      name: _text(json, 'name'),
      coverId: _optionalText(json, 'coverId'),
      createdAt: _time(json, 'createdAt'),
      modifiedAt: _time(json, 'modifiedAt'),
      entries: [for (final entry in entries) _decodeEntry(entry)],
    );
  }

  static PlaylistEntry _decodeEntry(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('an entry is not an object');
    }
    final durationMs = json['durationMs'];
    if (durationMs != null && durationMs is! int) {
      throw const FormatException('"durationMs" is not a whole number');
    }

    return PlaylistEntry(
      id: _text(json, 'id'),
      path: _text(json, 'path'),
      title: _optionalText(json, 'title'),
      artist: _optionalText(json, 'artist'),
      album: _optionalText(json, 'album'),
      duration: durationMs == null
          ? null
          : Duration(milliseconds: durationMs as int),
    );
  }

  static String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('"$key" is not a non-empty string');
    }

    return value;
  }

  static String? _optionalText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException('"$key" is not a string');
    }

    return value as String?;
  }

  static DateTime _time(Map<String, dynamic> json, String key) =>
      DateTime.parse(_text(json, key));
}
