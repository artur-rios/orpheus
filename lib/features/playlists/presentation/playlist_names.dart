import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/auto_playlists.dart';
import '../domain/playlist.dart';

/// [playlist] under the name it is shown by.
///
/// One of the owner's is [playlist] itself. An auto playlist comes without a
/// name — it is worked out where there is no locale to name it in (see
/// `autoPlaylists`) — and is given its localised one here, so that everything
/// downstream of the view (its title, the queue it plays as, the file it
/// exports to) reads `name` as it does for any playlist.
Playlist shownAs(Playlist playlist, AppLocalizations l10n) {
  final name = switch (playlist.id) {
    autoLatelyId => l10n.autoPlaylistLately,
    autoAllTimeId => l10n.autoPlaylistAllTime,
    _ => null,
  };
  if (name == null) return playlist;

  return Playlist(
    id: playlist.id,
    name: name,
    entries: playlist.entries,
    coverId: playlist.coverId,
    createdAt: playlist.createdAt,
    modifiedAt: playlist.modifiedAt,
  );
}
