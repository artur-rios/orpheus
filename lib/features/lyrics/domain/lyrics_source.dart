import 'lyrics.dart';

/// Where a track's words come from.
///
/// One seam, and a deliberately narrow one: a path in, the words out. What is
/// behind it reads files that are already on this machine — a `.lrc` beside
/// the track, or the track's own tags — and there is no implementation that
/// asks anything on a network, which is the same promise the rest of this
/// application makes about metadata and cover art.
abstract interface class LyricsSource {
  /// The words of the track at [path], or `null` where the machine holds
  /// none.
  Future<Lyrics?> of(String path);
}
