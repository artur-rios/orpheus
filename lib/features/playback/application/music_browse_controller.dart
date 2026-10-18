import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import 'music_navigator.dart';

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
class MusicBrowseController extends Notifier<MusicBrowseState>
    implements MusicNavigator {
  @override
  MusicBrowseState build() {
    // Where the owner has drilled to is named by tags, and a re-scan that
    // finds those tags changed would otherwise leave them inside a record
    // that no longer exists under that name: an empty list beneath a
    // breadcrumb naming what used to be there.
    ref.listen(musicLibraryControllerProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null && after != null) {
        state = followLibrary(
          state,
          before: before.entries,
          after: after.entries,
        );
      }
    });

    return const MusicBrowseState();
  }

  /// Shows [view], from the top.
  ///
  /// The drill is dropped rather than carried across: an owner switching to
  /// Albums asked for the albums list, not for whatever record happened to be
  /// open in the view they left.
  @override
  void show(MusicView view) => state = MusicBrowseState(view: view);

  /// Opens [artist]'s albums.
  @override
  void openArtist(String? artist) => state = MusicBrowseState(
    view: state.view,
    artist: artist,
    inArtist: true,
  );

  /// Opens [album]'s tracks. [artist] is the album's, which is what tells two
  /// records that share a title apart.
  @override
  void openAlbum(String? album, String? artist) => state = MusicBrowseState(
    view: state.view,
    artist: artist,
    album: album,
    inArtist: state.view == MusicView.artists,
    inAlbum: true,
  );

  /// Goes back to the top of the current view.
  @override
  void upToArtists() => state = MusicBrowseState(view: state.view);

  /// Goes back to the open artist's albums, or to the top of the view if no
  /// artist was open — which is the case for an album opened straight off the
  /// Albums view, where there is no artist to go back to.
  @override
  void upToArtist() => state = _upToArtistOf(state);

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

/// Where the owner is kept in [state] across a library that changed under
/// them, from [before] to [after].
///
/// A record or artist renamed by a re-tag is followed to its new name — found
/// through a file it held, which keeps its path whatever its tags now say. One
/// whose files are all gone is left, a level at a time, for the nearest level
/// that still has something in it.
///
/// A function of the state rather than a method of the Music tab's controller,
/// because the Music tab is not the only place that keeps one: a genre open in
/// Genres follows a re-tag by these same rules, over that genre's part of the
/// library. [state] itself comes back where nothing needed to change, so a
/// caller that assigns the result notifies no one.
MusicBrowseState followLibrary(
  MusicBrowseState state, {
  required List<MusicEntry> before,
  required List<MusicEntry> after,
}) {
  // Built only when something has to be followed, which most re-scans never
  // ask for: the owner's record is usually still there under its own name.
  Map<String, MusicEntry>? afterByPath;

  // The first of [entries] [after] still holds, as [after] now has it.
  MusicEntry? survivor(Iterable<MusicEntry> entries) {
    final byPath = afterByPath ??= {
      for (final entry in after) entry.file.path: entry,
    };
    for (final entry in entries) {
      if (byPath[entry.file.path] case final found?) return found;
    }

    return null;
  }

  var followed = state;

  if (followed.inAlbum) {
    if (tracksOfAlbum(followed.album, followed.artist, after).isNotEmpty) {
      return followed;
    }

    final moved = survivor(
      tracksOfAlbum(followed.album, followed.artist, before),
    );
    if (moved != null) {
      return MusicBrowseState(
        view: followed.view,
        artist: moved.albumArtist,
        album: moved.album,
        inArtist: followed.inArtist,
        inAlbum: true,
      );
    }

    followed = _upToArtistOf(followed);
  }

  if (followed.inArtist) {
    if (albumsOfArtist(followed.artist, after).isNotEmpty) return followed;

    final artist = followed.artist;
    final moved = survivor([
      for (final entry in before)
        if (entry.albumArtist == artist) entry,
    ]);
    if (moved != null) {
      return MusicBrowseState(
        view: followed.view,
        artist: moved.albumArtist,
        inArtist: true,
      );
    }

    followed = MusicBrowseState(view: followed.view);
  }

  return followed;
}

/// [state] one level out of a record: the open artist's albums, or the top of
/// the view where no artist was opened on the way in.
MusicBrowseState _upToArtistOf(MusicBrowseState state) => state.inArtist
    ? MusicBrowseState(view: state.view, artist: state.artist, inArtist: true)
    : MusicBrowseState(view: state.view);
