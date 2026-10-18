import '../../library/domain/music_entry.dart';
import '../../stats/domain/play_history.dart';
import 'playlist.dart';

/// The id of *Favourites lately*, which is also its key everywhere a playlist
/// is keyed: what is open, and the scope of a selection made in it.
const String autoLatelyId = 'auto:lately';

/// The id of *All-time favourites*; see [autoLatelyId].
const String autoAllTimeId = 'auto:all-time';

/// Whether [playlistId] names an auto playlist rather than one of the owner's
/// — which can be opened, played and exported, but not changed.
bool isAutoPlaylistId(String playlistId) =>
    playlistId == autoLatelyId || playlistId == autoAllTimeId;

/// How far back *lately* looks.
const Duration latelyWindow = Duration(days: 30);

/// How many songs an auto playlist holds at most.
const int autoPlaylistLimit = 50;

/// How many songs must have been played within [latelyWindow] — by a dated
/// play — before *Favourites lately* is ranked by those plays. Fewer, and the
/// list falls back to the songs last played within the window.
const int latelyEnough = 10;

/// An auto playlist's songs, in order.
class AutoList {
  /// Creates a list of [songs].
  const AutoList({required this.songs, this.isFallback = false});

  /// The songs, best first, at most [autoPlaylistLimit].
  final List<MusicEntry> songs;

  /// Whether there were too few recent plays to rank by them, so the songs are
  /// ranked on the weaker evidence of their last play — the playlist says so.
  ///
  /// Never true for an empty list: when nothing qualifies at all there is
  /// nothing to explain, and the empty state is all that is shown.
  final bool isFallback;
}

/// *Favourites lately*: what the owner has been playing for the last
/// [latelyWindow] before [now].
///
/// Only songs [catalogByPath] holds — a song that has left the library is not
/// played. When at least [latelyEnough] of them have a dated play within the
/// window, they are ranked by how many such plays they have, then by the
/// latest play. Otherwise — a history too young to say, or one migrated from
/// before plays were dated — the songs *last played* within the window are
/// ranked by their total plays, then by the latest play, and
/// [AutoList.isFallback] says so.
///
/// A time exactly [latelyWindow] before [now] is within it, as for the
/// history's own trimming. Times are compared as instants, so a local time
/// and the same moment in UTC are the same.
AutoList favouritesLately(
  PlayHistory history,
  Map<String, MusicEntry> catalogByPath,
  DateTime now,
) {
  final since = now.toUtc().subtract(latelyWindow);

  final recentCounts = <TrackPlays, int>{};
  for (final track in history.tracks.values) {
    if (!catalogByPath.containsKey(track.path)) continue;
    final count = track.recent
        .where((at) => !at.toUtc().isBefore(since))
        .length;
    if (count > 0) recentCounts[track] = count;
  }

  if (recentCounts.length >= latelyEnough) {
    final ranked = recentCounts.keys.toList()
      ..sort(
        (a, b) => _ordered(recentCounts[b]!.compareTo(recentCounts[a]!), a, b),
      );

    return AutoList(songs: _songs(ranked, catalogByPath));
  }

  final ranked = [
    for (final track in history.tracks.values)
      if (catalogByPath.containsKey(track.path) &&
          !track.lastPlayedAt.toUtc().isBefore(since))
        track,
  ]..sort((a, b) => _ordered(b.plays.compareTo(a.plays), a, b));

  return AutoList(
    songs: _songs(ranked, catalogByPath),
    isFallback: ranked.isNotEmpty,
  );
}

/// *All-time favourites*: the most played songs there are, whenever they were
/// played.
///
/// Only songs [catalogByPath] holds, and only those played at least once,
/// ranked by plays and then by the latest play.
List<MusicEntry> allTimeFavourites(
  PlayHistory history,
  Map<String, MusicEntry> catalogByPath,
) {
  final ranked = [
    for (final track in history.tracks.values)
      if (track.plays >= 1 && catalogByPath.containsKey(track.path)) track,
  ]..sort((a, b) => _ordered(b.plays.compareTo(a.plays), a, b));

  return _songs(ranked, catalogByPath);
}

/// [first] if it decides the order, and otherwise the later last play first,
/// and then the path — which no two tracks share, so that the order never
/// depends on how the history happened to be stored.
int _ordered(int first, TrackPlays a, TrackPlays b) {
  if (first != 0) return first;
  final later = b.lastPlayedAt.compareTo(a.lastPlayedAt);
  if (later != 0) return later;

  return a.path.compareTo(b.path);
}

List<MusicEntry> _songs(
  List<TrackPlays> ranked,
  Map<String, MusicEntry> catalogByPath,
) => [
  for (final track in ranked.take(autoPlaylistLimit))
    catalogByPath[track.path]!,
];

/// The two auto playlists as values the playlist views already know how to
/// show: *Favourites lately* first, then *All-time favourites*.
///
/// Synthesised for display and never stored. Each has its fixed id
/// ([autoLatelyId], [autoAllTimeId]) and **no name**: the name is a localised
/// string, and nothing here has a `BuildContext` to localise it with, so the
/// views map the id to the name they show. Each entry's id is the song's path
/// — a song is in a list once, so the path identifies the place — and its
/// snapshot is what [catalogByPath] says about the song now. The times are
/// fixed, so that a list does not look changed every time it is worked out.
List<Playlist> autoPlaylists(
  PlayHistory history,
  Map<String, MusicEntry> catalogByPath,
  DateTime now,
) => [
  _autoPlaylist(
    autoLatelyId,
    favouritesLately(history, catalogByPath, now).songs,
  ),
  _autoPlaylist(autoAllTimeId, allTimeFavourites(history, catalogByPath)),
];

/// The moment every auto playlist says it was made and last changed.
final DateTime _autoPlaylistTime = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);

Playlist _autoPlaylist(String id, List<MusicEntry> songs) => Playlist(
  id: id,
  name: '',
  entries: [
    for (final song in songs)
      PlaylistEntry(
        id: song.file.path,
        path: song.file.path,
      ).refreshedFrom(song),
  ],
  createdAt: _autoPlaylistTime,
  modifiedAt: _autoPlaylistTime,
);
