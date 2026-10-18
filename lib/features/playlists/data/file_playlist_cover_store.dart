import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../autofill/data/atomic_write.dart';
import '../domain/playlist_cover_store.dart';

/// [PlaylistCoverStore] as a directory of files, one per playlist.
///
/// The file is named after the playlist's id and has no extension: the bytes
/// are a JPEG or a PNG and whatever shows them can tell which. A picture is
/// replaced whole or not at all, so a cover being changed when the machine
/// goes down is the old cover or the new one.
class FilePlaylistCoverStore implements PlaylistCoverStore {
  /// Creates a store keeping its files in a `playlist-covers` folder inside
  /// [directory].
  FilePlaylistCoverStore(this.directory);

  /// The name of the folder inside [directory] holding the pictures.
  static const String folderName = 'playlist-covers';

  /// The folder the covers' folder is made in, beside the playlists document.
  final String directory;

  /// Where the pictures are.
  String get folder => p.join(directory, folderName);

  @override
  Future<void> put(String playlistId, Uint8List bytes) async {
    final path = _pathFor(playlistId);
    await Directory(folder).create(recursive: true);
    replaceFileAtomically(path, bytes);
  }

  @override
  Future<Uint8List?> read(String playlistId) async {
    final file = File(_pathFor(playlistId));
    if (!file.existsSync()) return null;

    try {
      return await file.readAsBytes();
    } on PathNotFoundException {
      // Deleted between the two questions: no cover.
      return null;
    }
  }

  @override
  Future<void> delete(String playlistId) async {
    final file = File(_pathFor(playlistId));
    if (file.existsSync()) await file.delete();
  }

  /// The file for [playlistId], which must name a file inside [folder] and
  /// nothing outside it.
  String _pathFor(String playlistId) {
    if (playlistId.isEmpty ||
        playlistId != p.basename(playlistId) ||
        playlistId == '.' ||
        playlistId == '..') {
      throw ArgumentError.value(
        playlistId,
        'playlistId',
        'must be a plain file name',
      );
    }

    return p.join(folder, playlistId);
  }
}
