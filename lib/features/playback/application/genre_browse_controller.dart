import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import 'music_browse_controller.dart';
import 'music_navigator.dart';

/// Where in Genres the owner is.
///
/// [inGenre] says whether a genre has been opened, rather than letting a null
/// [genre] mean it has not, for the reason [MusicBrowseState] does the same for
/// artists: the tracks that carry no genre are a real group an owner can open,
/// and a state that could not tell it from "nothing selected" would make it
/// unreachable.
class GenreBrowseState {
  /// Creates a state.
  const GenreBrowseState({
    this.inGenre = false,
    this.genre,
    this.music = const MusicBrowseState(),
  });

  /// Whether a genre has been opened.
  final bool inGenre;

  /// The `genreKey` of the genre opened, which is `null` for *No genre*.
  final String? genre;

  /// Where the owner is inside the open genre.
  ///
  /// The same state the Music tab keeps, because a genre is browsed with the
  /// same views and the same drills; it is only ever the genre's own part of
  /// the library that it is read against.
  final MusicBrowseState music;
}

/// The Genres tab's navigation.
///
/// Its own place, apart from [MusicBrowseController]'s: a drill under Rock must
/// not move the Music tab, nor the other way round.
class GenreBrowseController extends Notifier<GenreBrowseState>
    implements MusicNavigator {
  @override
  GenreBrowseState build() {
    // Where the owner has got to is named by tags, and a re-scan that finds
    // those tags changed would otherwise leave them inside a genre or a record
    // that no longer exists under that name.
    ref.listen(musicLibraryControllerProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null && after != null) {
        _followLibrary(before: before.entries, after: after.entries);
      }
    });

    return const GenreBrowseState();
  }

  /// Opens the genre [key] names, from its top, in the Artists view. `null` is
  /// *No genre*.
  void openGenre(String? key) =>
      state = GenreBrowseState(inGenre: true, genre: key);

  /// Goes back to the list of genres.
  void closeGenre() => state = const GenreBrowseState();

  /// Shows [view], from the top of the open genre.
  @override
  void show(MusicView view) => _move(MusicBrowseState(view: view));

  /// Opens [artist]'s records in the open genre.
  @override
  void openArtist(String? artist) => _move(
    MusicBrowseState(view: state.music.view, artist: artist, inArtist: true),
  );

  /// Opens [album]'s tracks. [artist] is the album's, which is what tells two
  /// records that share a title apart.
  @override
  void openAlbum(String? album, String? artist) => _move(
    MusicBrowseState(
      view: state.music.view,
      artist: artist,
      album: album,
      inArtist: state.music.view == MusicView.artists,
      inAlbum: true,
    ),
  );

  /// Goes back to the top of the open genre, or to the list where the genre is
  /// no longer there to be at the top of.
  ///
  /// The library is asked rather than assumed: an owner left on a record by a
  /// re-scan can go up after the genre itself has gone.
  @override
  void upToArtists() {
    if (_genreExists(state.genre, _library())) {
      _move(MusicBrowseState(view: state.music.view));
    } else {
      closeGenre();
    }
  }

  /// Goes back to the open artist's records when that artist still has any in
  /// the genre, and to the genre's top when they do not — which is also where an
  /// album opened straight off the Albums view goes, there being no artist to
  /// go back to.
  ///
  /// Asked of the library because an owner can stay on a record whose genre tag
  /// was edited away; the artist's records are then not what they were when the
  /// record was opened, and landing on an empty list is the one place worse
  /// than where they came from.
  @override
  void upToArtist() {
    final music = state.music;
    if (music.inArtist &&
        albumsOfArtist(
          music.artist,
          genreLibrary(state.genre, _library()),
        ).isNotEmpty) {
      _move(
        MusicBrowseState(
          view: music.view,
          artist: music.artist,
          inArtist: true,
        ),
      );

      return;
    }

    upToArtists();
  }

  /// Steps one level out, and answers whether there was one to step out of.
  ///
  /// What the system back gesture calls on Android. `false` means the list of
  /// genres is already showing, and the gesture belongs to whatever is behind
  /// it.
  bool back() {
    if (state.music.inAlbum) {
      upToArtist();

      return true;
    }
    if (state.music.inArtist) {
      upToArtists();

      return true;
    }
    if (state.inGenre) {
      closeGenre();

      return true;
    }

    return false;
  }

  /// Keeps the open genre, with [music] as the owner's place in it.
  void _move(MusicBrowseState music) => state = GenreBrowseState(
    inGenre: state.inGenre,
    genre: state.genre,
    music: music,
  );

  /// The library as it is now.
  List<MusicEntry> _library() =>
      ref.read(musicLibraryControllerProvider).value?.entries ?? const [];

  /// Whether some track of [library] belongs to the genre [key] names.
  ///
  /// Through [hasGenre], the rule the list's groups are built by, so that what
  /// counts as there is exactly what the list would show — and a stop at the
  /// first match rather than the whole list built, because this runs on every
  /// way up and every library change while a genre is open.
  bool _genreExists(String? key, List<MusicEntry> library) =>
      library.any((entry) => hasGenre(entry, key));

  /// Keeps the owner where they were across a library that changed under them,
  /// from [before] to [after].
  ///
  /// A genre with nothing left in it sends them to the list. A record they are
  /// on that is still in the library is left alone even when its genre tag is
  /// gone: it is where they chose to be, and the way up lands somewhere the
  /// genre still has something. Anything else is followed by the Music tab's
  /// rules, over the genre's part of the library.
  void _followLibrary({
    required List<MusicEntry> before,
    required List<MusicEntry> after,
  }) {
    if (!state.inGenre) return;

    final genre = state.genre;
    if (!_genreExists(genre, after)) {
      closeGenre();

      return;
    }

    final music = state.music;
    if (music.inAlbum &&
        tracksOfAlbum(music.album, music.artist, after).isNotEmpty) {
      return;
    }

    final followed = followLibrary(
      music,
      before: genreLibrary(genre, before),
      after: genreLibrary(genre, after),
    );
    if (!identical(followed, music)) _move(followed);
  }
}
