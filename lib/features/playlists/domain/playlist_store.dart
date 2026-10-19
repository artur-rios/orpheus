import 'playlist.dart';

/// Where the owner's playlists are kept between runs.
///
/// All of them at once: the list is small, it is read once when the
/// application starts, and every change writes it whole — which is what makes
/// a write all-or-nothing rather than a set of files that can disagree.
abstract interface class PlaylistStore {
  /// Every stored playlist, in the order they were written.
  ///
  /// Empty when none were stored, and also when what was stored could not be
  /// understood: that is set aside rather than overwritten, so the next write
  /// does not destroy it.
  ///
  /// Throws when what was stored could neither be read nor set aside: an
  /// answer of "none" there would be followed by a write over the owner's
  /// playlists.
  Future<List<Playlist>> read();

  /// Stores [all], replacing whatever was stored.
  ///
  /// Throws when the playlists could not be stored; what was stored before is
  /// then as it was.
  Future<void> write(List<Playlist> all);
}
