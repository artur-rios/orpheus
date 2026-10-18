import '../../library/domain/music_entry.dart';
import 'playlist.dart';

/// The most covers a mosaic shows.
const int mosaicSize = 4;

/// The covers a playlist's mosaic is drawn from.
///
/// The cover of each of the first four distinct albums among the playlist's
/// songs, in playlist order. Only songs the catalog still has count, so a
/// missing file cannot hold a place; an album is told apart the way the
/// library tells records apart, by title *and* album artist; and a song whose
/// record has no cover does not take a place that a later song of another
/// record could fill. A song with no album at all is told apart by its
/// cover instead. Empty when there is nothing to draw, which is when the playlist
/// shows a placeholder.
List<String> mosaicCoverIds(
  Playlist playlist,
  Map<String, MusicEntry> catalogByPath,
) {
  final seen = <Object>{};
  final covers = <String>[];
  for (final entry in playlist.entries) {
    final song = catalogByPath[entry.path];
    final coverId = song?.metadata.coverId;
    if (song == null || coverId == null) continue;
    final album = song.album;
    final record = album == null ? coverId : (album, song.albumArtist);
    if (!seen.add(record)) continue;
    covers.add(coverId);
    if (covers.length == mosaicSize) break;
  }
  return covers;
}
