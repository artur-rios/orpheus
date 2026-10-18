import 'music_browse_controller.dart';

/// What the music browser's rows, breadcrumb and view switcher steer.
///
/// An interface rather than the Music tab's controller itself because the
/// browser is not only the Music tab's: a genre opened in Genres is browsed
/// with the same views and the same drills, and where the owner has got to
/// there is that tab's own place — a drill under Rock must not move the Music
/// tab, nor the other way round. Each screen hands the browser the navigator
/// that keeps its place.
abstract interface class MusicNavigator {
  /// Shows [view], from the top.
  void show(MusicView view);

  /// Opens [artist]'s records, `null` being the untagged group.
  void openArtist(String? artist);

  /// Opens [album]'s tracks. [artist] is the album's, which is what tells two
  /// records that share a title apart.
  void openAlbum(String? album, String? artist);

  /// Goes back to the top of the current view.
  void upToArtists();

  /// Goes back to the open artist's records, or to the top of the view where
  /// no artist was opened on the way in.
  void upToArtist();
}
