import '../../library/domain/genres.dart';
import '../../library/domain/music_entry.dart';

/// What plays once a queue has run out, as the owner chose in the
/// preferences.
enum QueueContinuation {
  /// Nothing: playback stops at the end of the last track, as it always did.
  stop,

  /// A random track by the artist of the track that ended.
  sameArtist,

  /// A random track sharing a genre with the track that ended.
  sameGenre,

  /// A random track from anywhere in the library.
  library;

  /// The mode stored as [name], or [stop] for none or one this release does
  /// not know — so a preference written by a later release, or a corrupt one,
  /// behaves as a fresh install does rather than as a guess.
  static QueueContinuation fromName(String? name) =>
      values.asNameMap()[name] ?? stop;
}

/// The settings key the owner's [QueueContinuation] is stored under.
const String queueContinuationSettingsKey = 'queueContinuation';

/// The tracks of [library] that may follow a queue which ran out on
/// [seedPath]; empty means playback stops.
///
/// Only the rule: which one plays is drawn by the caller, which owns the
/// randomness and knows which files are still on disk.
///
/// The seed is read from [library] rather than handed over, because the
/// queue holds files and the rule needs their tags. A seed the library no
/// longer has — removed since the queue was built — continues from the whole
/// library, as a seed with no artist or no genre does: the owner asked for
/// the music to keep going, and a missing tag is no reason for silence.
///
/// [queuedPaths] are left out so that the next track is not one just heard,
/// until nothing else is left; then they are offered again, except the seed
/// itself, which would be the track that just ended starting over.
/// [skippedPaths] are never offered: they are the tracks that would not
/// play, and offering them again is how a queue would loop on them for ever.
List<MusicEntry> continuationPool({
  required QueueContinuation mode,
  required String? seedPath,
  required List<MusicEntry> library,
  required Set<String> queuedPaths,
  required Set<String> skippedPaths,
}) {
  if (mode == QueueContinuation.stop) return const [];

  MusicEntry? seed;
  for (final entry in library) {
    if (entry.file.path == seedPath) {
      seed = entry;
      break;
    }
  }

  final matches = _matcher(mode, seed);
  final playable = [
    for (final entry in library)
      if (!skippedPaths.contains(entry.file.path) && matches(entry)) entry,
  ];

  final fresh = [
    for (final entry in playable)
      if (!queuedPaths.contains(entry.file.path)) entry,
  ];
  if (fresh.isNotEmpty) return fresh;

  return [
    for (final entry in playable)
      if (entry.file.path != seedPath) entry,
  ];
}

/// Which tracks [mode] keeps, given [seed].
///
/// The artist is the seed's performer before its album artist, so a track
/// off a compilation continues with the person singing it rather than with
/// "Various Artists"; a candidate matches by either of its own, so that
/// performer's records count whoever their album artist is. Names are
/// compared as `artistOf` compares them, exactly.
bool Function(MusicEntry) _matcher(QueueContinuation mode, MusicEntry? seed) {
  bool everything(MusicEntry _) => true;
  if (seed == null) return everything;

  switch (mode) {
    case QueueContinuation.sameArtist:
      final artist = seed.artist ?? seed.albumArtist;
      if (artist == null) return everything;

      return (entry) => entry.artist == artist || entry.albumArtist == artist;
    case QueueContinuation.sameGenre:
      final genres = {for (final genre in seed.genres) genreKey(genre)};
      if (genres.isEmpty) return everything;

      return (entry) => entry.genres.any((g) => genres.contains(genreKey(g)));
    case QueueContinuation.library:
    case QueueContinuation.stop:
      return everything;
  }
}
