import 'lyrics.dart';

/// Where a track's words come from on this machine.
///
/// One seam, and a deliberately narrow one: a path in, the words out. What is
/// behind it reads files that are already here — a `.lrc` beside the track, or
/// the track's own tags — and it is asked first for every track, always. Only
/// when it answers `null` is the remote source reached at all, and only
/// then if the owner has left the lookup on.
///
/// The order is the whole rule: the owner's own files decide what a track's
/// words are, and a network is the fallback for the tracks they have none for.
abstract interface class LyricsSource {
  /// The words of the track at [path], or `null` where the machine holds
  /// none.
  Future<Lyrics?> of(String path);
}
