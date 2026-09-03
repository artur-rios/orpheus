import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of the music area's three views is shown.
enum MusicView {
  /// Every artist, drilled into for their albums.
  artists,

  /// Every album, drilled into for its tracks.
  albums,

  /// Every track in the library.
  songs,
}

/// Where in the music area the owner is.
///
/// [inArtist] and [inAlbum] say whether a drill has happened, rather than
/// letting a null [artist] mean it has not: the files that name no artist are
/// a real group an owner can open, and a state that could not tell that group
/// from "nothing selected" would make it unreachable.
class MusicBrowseState {
  /// Creates a state.
  const MusicBrowseState({
    this.view = MusicView.artists,
    this.artist,
    this.album,
    this.inArtist = false,
    this.inAlbum = false,
  });

  /// The view the segmented control shows.
  final MusicView view;

  /// The album artist drilled into, which is `null` for the untagged group.
  ///
  /// The album's own artist rather than any one track's performer, because
  /// that is what the artist and album lists are grouped by: it is the key
  /// `albumsOfArtist` and `tracksOfAlbum` are asked with, so a compilation
  /// opens on the whole record rather than on one performer.
  final String? artist;

  /// The album drilled into, which is `null` for the untitled group.
  final String? album;

  /// Whether an artist has been opened.
  final bool inArtist;

  /// Whether an album has been opened.
  final bool inAlbum;
}

/// The music area's navigation.
class MusicBrowseController extends Notifier<MusicBrowseState> {
  @override
  MusicBrowseState build() => const MusicBrowseState();

  /// Shows [view], from the top.
  ///
  /// The drill is dropped rather than carried across: an owner switching to
  /// Albums asked for the albums list, not for whatever record happened to be
  /// open in the view they left.
  void show(MusicView view) => state = MusicBrowseState(view: view);

  /// Opens [artist]'s albums.
  void openArtist(String? artist) => state = MusicBrowseState(
    view: state.view,
    artist: artist,
    inArtist: true,
  );

  /// Opens [album]'s tracks. [artist] is the album's, which is what tells two
  /// records that share a title apart.
  void openAlbum(String? album, String? artist) => state = MusicBrowseState(
    view: state.view,
    artist: artist,
    album: album,
    inArtist: state.view == MusicView.artists,
    inAlbum: true,
  );

  /// Goes back to the top of the current view.
  void upToArtists() => state = MusicBrowseState(view: state.view);

  /// Goes back to the open artist's albums, or to the top of the view if no
  /// artist was open — which is the case for an album opened straight off the
  /// Albums view, where there is no artist to go back to.
  void upToArtist() {
    if (!state.inArtist) {
      upToArtists();

      return;
    }

    state = MusicBrowseState(
      view: state.view,
      artist: state.artist,
      inArtist: true,
    );
  }

  /// Steps one level out, and answers whether there was one to step out of.
  ///
  /// What the system back gesture calls on Android: a phone has no breadcrumb
  /// wide enough to be worth showing, and the back button is what an owner
  /// reaches for instead. `false` means the music area is already at the top,
  /// and the gesture belongs to whatever is behind it.
  bool back() {
    if (state.inAlbum) {
      upToArtist();

      return true;
    }
    if (state.inArtist) {
      upToArtists();

      return true;
    }

    return false;
  }
}
