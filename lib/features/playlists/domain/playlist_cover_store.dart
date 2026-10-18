import 'dart:typed_data';

/// Where the pictures the owner chose as playlist covers are kept.
///
/// Keyed by the playlist's id rather than by the picture's content, unlike the
/// album covers: two playlists given the same picture each own a copy, so
/// deleting one playlist can never take another's cover with it.
abstract interface class PlaylistCoverStore {
  /// Stores [bytes] as the cover of the playlist [playlistId], replacing any
  /// it had.
  Future<void> put(String playlistId, Uint8List bytes);

  /// The cover of the playlist [playlistId], or `null` when it has none.
  Future<Uint8List?> read(String playlistId);

  /// Removes the cover of the playlist [playlistId]; nothing happens when it
  /// has none.
  Future<void> delete(String playlistId);
}
