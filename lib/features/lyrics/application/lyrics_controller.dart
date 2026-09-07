import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../domain/lyrics.dart';
import '../domain/remote_lyrics_source.dart';

/// One track's words, looked for once and kept while the player shows them.
///
/// Asynchronous because finding them is a file read — a sidecar, or the
/// track's own header — and, for a track this machine holds none for, a
/// lookup over a network. The screen cannot wait on either.
///
/// The order is the feature, and it never varies:
///
/// 1. What this machine holds, through [LyricsSource]. A `.lrc` beside the
///    track, then its `SYLT` frame, then its lyrics tag. Whatever this answers
///    is the answer, and nothing else is asked.
/// 2. Only then, and only if the owner has left the lookup on, the service —
///    with the track's artist and title, and nothing about this machine.
/// 3. A sheet that came back is written beside the track as a `.lrc`, so the
///    next launch finds it at step 1 and asks nobody anything. A write that is
///    refused costs the owner that, and nothing in this session.
///
/// It answers `null` for every track no words were found for anywhere, and the
/// panel says so rather than showing an empty frame.
///
/// Keyed by the track's path and auto-disposed with it, for the reason the
/// spectrum is: a queue moves on, and the words of every track ever played
/// would otherwise be held for the life of the container.
class LyricsController extends AsyncNotifier<Lyrics?> {
  /// Creates the controller for the track at [path].
  LyricsController(this.path);

  /// The track whose words these are.
  final String path;

  static final Logger _log = Logger('lyrics');

  @override
  Future<Lyrics?> build() async {
    // Every dependency read before the first await: the owner who closes the
    // player mid-read disposes this, and reaching for one after that throws.
    final source = ref.read(lyricsSourceProvider);
    final remote = ref.read(remoteLyricsSourceProvider);
    final sidecar = ref.read(lyricsSidecarProvider);
    final fetches = ref.read(settingsStoreProvider).fetchesLyricsOnline;
    final library = ref.read(musicLibraryControllerProvider.future);

    final local = await source.of(path);
    if (local != null) return local;

    if (!fetches) return null;

    final query = await _queryFor(library);
    if (query == null) return null;

    try {
      final found = await remote.find(query);
      if (found == null) return null;

      // Awaited rather than left running: the write is what makes this the
      // last lookup for this track, and a test that could not see it land
      // would be asserting the half of the flow that costs nothing.
      await sidecar.write(path, found.text);

      return found.lyrics;
    } on Object catch (error) {
      // The seam's own contract is that it answers `null` rather than
      // throwing, and the one implementation keeps it. This is here for the
      // case where it does not: a lookup is a convenience over a track that
      // already has no words, and the panel's empty state is a truer thing to
      // show for it than a failure with a retry button — which is what an
      // escaping error would turn every unreachable network into.
      _log.fine('the words of $path could not be looked up', error);

      return null;
    }
  }

  /// What to ask the service about this track, or `null` where its tags do not
  /// say enough to ask.
  ///
  /// Both a title and an artist, or nothing. A lookup on a title alone is not
  /// a lookup, it is a guess between every recording that shares the name —
  /// and a file tagged that poorly is exactly the file whose words would come
  /// back belonging to somebody else's song.
  Future<LyricsQuery?> _queryFor(Future<MusicCatalog> library) async {
    final MusicEntry? entry;
    try {
      entry = (await library).entryAt(path);
    } on Object catch (error) {
      // A library that will not load is a condition the library screen already
      // reports. Here it is one more track with no words, rather than a second
      // report of the same fault inside the player.
      _log.fine('the library was not available to look up the words', error);

      return null;
    }

    if (entry == null) return null;

    final title = trimmedOrNull(entry.metadata.title);
    final artist = entry.artist ?? entry.albumArtist;
    if (title == null || artist == null) return null;

    return LyricsQuery(
      title: title,
      artist: artist,
      album: entry.album,
      duration: entry.metadata.duration,
    );
  }
}
