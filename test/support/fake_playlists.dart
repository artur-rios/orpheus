import 'dart:typed_data';

import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/domain/playlist_cover_store.dart';
import 'package:orpheus/features/playlists/domain/playlist_store.dart';

/// A [PlaylistStore] in memory, so that no test writes a document to disk.
class FakePlaylistStore implements PlaylistStore {
  /// Creates a store holding [playlists].
  FakePlaylistStore([List<Playlist> playlists = const []])
    : playlists = [...playlists];

  /// What is stored.
  List<Playlist> playlists;

  /// How many times the playlists were written.
  int writes = 0;

  /// When set, the next [write] throws it instead of storing anything, once.
  Exception? failNextWrite;

  @override
  Future<List<Playlist>> read() async => [...playlists];

  @override
  Future<void> write(List<Playlist> all) async {
    final failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      throw failure;
    }

    writes++;
    playlists = [...all];
  }
}

/// A [PlaylistCoverStore] in memory.
class FakePlaylistCoverStore implements PlaylistCoverStore {
  /// The pictures, by playlist id.
  final Map<String, Uint8List> covers = {};

  /// The ids deleted, in order.
  final List<String> deleted = [];

  @override
  Future<void> put(String playlistId, Uint8List bytes) async {
    covers[playlistId] = bytes;
  }

  @override
  Future<Uint8List?> read(String playlistId) async => covers[playlistId];

  @override
  Future<void> delete(String playlistId) async {
    deleted.add(playlistId);
    covers.remove(playlistId);
  }
}

/// A [FileSaver] that records what it was asked to save.
class FakeFileSaver implements FileSaver {
  /// Where the owner will say to put the file; `null` is a cancelled dialog.
  String? next = '/exports/saved';

  /// When set, [save] throws it instead of answering.
  Exception? failure;

  /// The names offered and the bytes saved, in order.
  final List<({String suggestedName, Uint8List bytes})> saved = [];

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final error = failure;
    if (error != null) throw error;

    final destination = next;
    if (destination != null) {
      saved.add((suggestedName: suggestedName, bytes: bytes));
    }

    return destination;
  }
}
