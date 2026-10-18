import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../domain/file_saver.dart';
import '../domain/m3u.dart';
import '../domain/playlist.dart';

/// The owner's playlists: what they are, and every way of changing them.
///
/// **Every change is written whole, then shown.** The store is given the full
/// list and only once it has taken it does [state] change, so what the screen
/// shows is never ahead of what is on disk, and a write that fails leaves both
/// as they were.
///
/// **Changes are serialised.** Each is a read-modify-write of the whole list,
/// and the views fire them without waiting — two quick adds would otherwise
/// both start from the same list, and the second would write over the first.
/// They are queued instead, so each starts from what the one before it left.
/// A change that fails does not hold up the ones behind it.
///
/// **An unreadable store refuses every change.** When the stored document
/// could neither be read nor set aside, [state] is an error and not an empty
/// list, because writing "the owner's playlists, plus this one" over a
/// document nobody has read would destroy it. Each change throws a
/// [StateError] instead.
class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  static final Logger _log = Logger('playlists');

  Future<void> _turn = Future<void>.value();

  @override
  Future<List<Playlist>> build() => ref.read(playlistStoreProvider).read();

  /// Makes an empty playlist called [name] and stores it after the others.
  ///
  /// Throws an [ArgumentError] when [name] is blank.
  Future<Playlist> create(String name) {
    final valid = validPlaylistName(name);
    if (valid == null) {
      return Future.error(ArgumentError.value(name, 'name', 'is blank'));
    }

    return _serialised(() async {
      final all = await _loaded();
      final at = ref.read(clockProvider)();
      final playlist = Playlist(
        id: ref.read(idGeneratorProvider)(),
        name: valid,
        createdAt: at,
        modifiedAt: at,
      );
      await _commit([...all, playlist]);
      return playlist;
    });
  }

  /// Adds [songs] to the end of the playlist [playlistId], in the order given,
  /// and returns how many were added.
  ///
  /// With [skipDuplicates], a song whose file is already in the playlist is
  /// left out. A song that is in [songs] twice is added twice either way: the
  /// owner chose that list, and only what is *already there* is a question.
  /// Adding nothing writes nothing.
  Future<int> add(
    String playlistId,
    List<MusicEntry> songs, {
    required bool skipDuplicates,
  }) async {
    var added = 0;
    await _edit(playlistId, (playlist) {
      final present = skipDuplicates ? playlist.pathsIn() : const <String>{};
      final entries = [
        for (final song in songs)
          if (!present.contains(song.file.path)) _snapshotOf(song),
      ];
      added = entries.length;
      if (entries.isEmpty) return playlist;

      return playlist.adding(entries, ref.read(clockProvider)());
    });
    return added;
  }

  /// Takes the entries whose ids are in [entryIds] out of the playlist
  /// [playlistId].
  Future<void> remove(String playlistId, Set<String> entryIds) => _edit(
    playlistId,
    (playlist) => playlist.removing(entryIds, ref.read(clockProvider)()),
  );

  /// Moves the entry [entryId] of the playlist [playlistId] to just before
  /// the entry [beforeEntryId], or to the end when that is `null`.
  ///
  /// Named by entry id, and resolved against the stored list when this
  /// change's turn comes, not when it was asked for: the owner's drop was
  /// worked out on the order they saw, which a change queued ahead of it —
  /// or one that failed — can make different from the stored one. An entry
  /// that is gone by then is not moved; a [beforeEntryId] that is gone sends
  /// the entry to the end (see `Playlist.movingEntry`).
  Future<void> move(
    String playlistId,
    String entryId, {
    String? beforeEntryId,
  }) => _edit(
    playlistId,
    (playlist) => playlist.movingEntry(
      entryId,
      beforeEntryId,
      ref.read(clockProvider)(),
    ),
  );

  /// Calls the playlist [playlistId] [name].
  ///
  /// Throws an [ArgumentError] when [name] is blank.
  Future<void> rename(String playlistId, String name) => _edit(
    playlistId,
    (playlist) => playlist.renamed(name, ref.read(clockProvider)()),
  );

  /// Gives the playlist [playlistId] the picture [bytes] as its cover.
  ///
  /// The picture is stored first, under the playlist's id: if the list then
  /// fails to be written the playlist still names the cover it had, and only
  /// the file behind it is the new one.
  Future<void> setCover(String playlistId, Uint8List bytes) =>
      _edit(playlistId, (playlist) async {
        await ref.read(playlistCoverStoreProvider).put(playlistId, bytes);
        return playlist.withCover(playlistId, ref.read(clockProvider)());
      });

  /// Takes the custom cover off the playlist [playlistId], so that it shows
  /// the mosaic again.
  Future<void> removeCover(String playlistId) => _edit(
    playlistId,
    (playlist) => playlist.coverId == null
        ? playlist
        : playlist.withCover(null, ref.read(clockProvider)()),
    afterWrite: () => _deleteCover(playlistId),
  );

  /// Deletes the playlist [playlistId] and its cover, and nothing else: the
  /// songs are the library's.
  ///
  /// Deleting a playlist that is not there is not an error — the second of two
  /// quick taps finds it already gone.
  Future<void> delete(String playlistId) => _serialised(() async {
    final all = await _loaded();
    if (!all.any((playlist) => playlist.id == playlistId)) return;

    await _commit([
      for (final playlist in all)
        if (playlist.id != playlistId) playlist,
    ]);
    await _deleteCover(playlistId);
  });

  /// Offers the playlist [playlistId] to the owner as `<name>.m3u` and saves
  /// it where they say.
  ///
  /// Returns where it went, or `null` when they cancelled. Throws when the
  /// file could not be saved. Not queued with the changes: it writes nothing
  /// of the playlists', and it would hold every change behind it for as long
  /// as the owner took to choose a place.
  Future<SavedFile?> exportM3u(String playlistId) async {
    final playlist = _find(await _loaded(), playlistId);
    final catalog =
        ref.read(musicLibraryControllerProvider).value?.byPath ?? const {};
    final text = playlistToM3u(playlist, catalog);

    return ref
        .read(fileSaverProvider)
        .save(
          suggestedName: '${playlist.name}.m3u',
          bytes: Uint8List.fromList(utf8.encode(text)),
        );
  }

  /// Runs [edit] on the playlist [playlistId] and stores the result.
  ///
  /// An [edit] that answers the playlist it was given changed nothing, and
  /// nothing is written. [afterWrite] runs once the list is stored.
  Future<void> _edit(
    String playlistId,
    FutureOr<Playlist> Function(Playlist playlist) edit, {
    Future<void> Function()? afterWrite,
  }) => _serialised(() async {
    final all = await _loaded();
    final playlist = _find(all, playlistId);
    final edited = await edit(playlist);
    if (identical(edited, playlist)) return;

    await _commit([
      for (final candidate in all)
        if (candidate.id == playlistId) _refreshed(edited) else candidate,
    ]);
    if (afterWrite != null) await afterWrite();
  });

  /// Runs [job] after every one queued before it has finished.
  Future<T> _serialised<T>(Future<T> Function() job) {
    final done = _turn.then((_) => job());
    _turn = done.then((_) {}, onError: (_) {});
    return done;
  }

  /// The playlists as they are now, or a [StateError] when they could not be
  /// read and so must not be written over.
  Future<List<Playlist>> _loaded() async {
    try {
      return await future;
    } on Object catch (error) {
      throw StateError(
        'The playlists could not be read, so none is changed: $error',
      );
    }
  }

  Playlist _find(List<Playlist> all, String playlistId) {
    for (final playlist in all) {
      if (playlist.id == playlistId) return playlist;
    }
    throw StateError('There is no playlist $playlistId.');
  }

  Future<void> _commit(List<Playlist> next) async {
    await ref.read(playlistStoreProvider).write(next);
    state = AsyncData(next);
  }

  /// The cover file is only a file: once the list no longer names it, failing
  /// to remove it leaves a stray picture, which is not worth failing the
  /// change that is already stored.
  Future<void> _deleteCover(String playlistId) async {
    try {
      await ref.read(playlistCoverStoreProvider).delete(playlistId);
    } on Object catch (error) {
      _log.warning('Could not delete the cover of $playlistId: $error');
    }
  }

  PlaylistEntry _snapshotOf(MusicEntry song) => PlaylistEntry(
    id: ref.read(idGeneratorProvider)(),
    path: song.file.path,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
  );

  /// [playlist] with each entry whose song is in the catalog told what the
  /// catalog says about it now. Nothing changes while the catalog is loading:
  /// a snapshot is only replaced by something known.
  Playlist _refreshed(Playlist playlist) {
    final catalog = ref.read(musicLibraryControllerProvider).value?.byPath;
    if (catalog == null) return playlist;

    return Playlist(
      id: playlist.id,
      name: playlist.name,
      entries: [
        for (final entry in playlist.entries)
          if (catalog[entry.path] case final song?)
            entry.refreshedFrom(song)
          else
            entry,
      ],
      coverId: playlist.coverId,
      createdAt: playlist.createdAt,
      modifiedAt: playlist.modifiedAt,
    );
  }
}
