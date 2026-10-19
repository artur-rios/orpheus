import 'dart:convert';
import 'dart:typed_data';

import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../playlists/domain/auto_playlists.dart';
import '../../playlists/domain/playlist.dart';
import '../../stats/domain/music_stats.dart';
import '../../stats/domain/play_history.dart';

/// The `format` the document names itself by.
const String dataExportFormat = 'orpheus-data';

/// The `formatVersion` of the layout [buildDataExport] writes.
const int dataExportFormatVersion = 1;

/// A source the export could not read at all.
///
/// Reported in the document's `problems` rather than thrown, because a partial
/// backup the owner knows about beats none: the section is empty and this says
/// which and why.
class ExportProblem {
  /// Creates a problem.
  const ExportProblem(this.section, this.message);

  /// The section of the document that is empty because of it.
  final String section;

  /// What went wrong, for a person to read.
  final String message;
}

/// Everything the export reads, handed over as plain values.
///
/// The domain knows nothing of providers or stores: whoever gathers the data
/// builds one of these, and [buildDataExport] only turns it into a document.
class ExportSources {
  /// Creates the sources.
  const ExportSources({
    required this.songs,
    required this.playlists,
    required this.history,
    required this.now,
    this.orpheusVersion,
    this.problems = const [],
  });

  /// The catalog, in the library's song order (`songsIn`).
  ///
  /// The order is what the song ids are numbered by, so it is the caller's to
  /// choose and this does not re-sort it.
  final List<MusicEntry> songs;

  /// The owner's playlists, as stored.
  final List<Playlist> playlists;

  /// Every track the owner has played.
  final PlayHistory history;

  /// When the export is made: `exportedAt`, and the instant the *Favourites
  /// lately* window is measured back from.
  final DateTime now;

  /// The version of the application writing the file, or `null` when unknown.
  final String? orpheusVersion;

  /// The sources that could not be read.
  final List<ExportProblem> problems;
}

/// The name of the lately auto playlist in the file, never localised.
const String _latelyName = 'Favourites lately';

/// The name of the all-time auto playlist in the file, never localised.
const String _allTimeName = 'All-time favourites';

/// The document an owner's data is exported as, with its keys in the order
/// they are written.
///
/// Plain maps, lists, strings, numbers, booleans and `null`s only, so it can
/// cross an isolate or be handed to a JSON encoder unchanged. The layout is
/// documented in `docs/data-export.md`.
Map<String, Object?> buildDataExport(ExportSources sources) {
  final songs = sources.songs;
  final catalog = MusicCatalog(entries: songs);

  // A reference used only inside the file: a restore matches songs by path and
  // tags, never by these.
  final idsByPath = <String, String>{
    for (var i = 0; i < songs.length; i++) songs[i].file.path: 's${i + 1}',
  };
  String? idOf(String path) => idsByPath[path];
  List<String> idsOf(Iterable<MusicEntry> entries) => [
    for (final entry in entries) idsByPath[entry.file.path]!,
  ];

  final stats = musicStatsFrom(history: sources.history, catalog: catalog);

  return {
    'format': dataExportFormat,
    'formatVersion': dataExportFormatVersion,
    'exportedAt': _time(sources.now),
    'orpheusVersion': sources.orpheusVersion,
    'songs': [
      for (final song in songs) _song(idsByPath[song.file.path]!, song),
    ],
    'artists': [
      for (final artist in artistsIn(songs))
        {'name': artist.name, 'songs': idsOf(artist.entries)},
    ],
    'albums': [
      for (final album in albumsIn(songs))
        {
          'title': album.name,
          'albumArtist': album.entries.first.albumArtist,
          'year': _commonYear(album.entries),
          'songs': idsOf(album.entries),
        },
    ],
    'playlists': [
      for (final playlist in sources.playlists) _playlist(playlist, idOf),
    ],
    'autoPlaylists': _autoPlaylists(sources, catalog, idsOf),
    'playHistory': [
      for (final track in sources.history.tracks.values)
        {
          'path': track.path,
          'songId': idOf(track.path),
          'plays': track.plays,
          'lastPlayedAt': _time(track.lastPlayedAt),
          'recentPlays': [for (final at in track.recent) _time(at)],
        },
    ],
    'statistics': {
      'totalPlays': stats.totalPlays,
      'distinctTracks': stats.distinctTracks,
      'untaggedTracks': stats.untaggedTracks,
      'topTracks': _ranked(stats.tracks),
      'topArtists': _ranked(stats.artists),
      'topAlbums': _ranked(stats.albums),
      'topGenres': _ranked(stats.genres),
    },
    'problems': [
      for (final problem in sources.problems)
        {'section': problem.section, 'message': problem.message},
    ],
  };
}

/// [document] as UTF-8 JSON, indented by two spaces, ending in a newline.
///
/// Kept apart from [buildDataExport] because encoding a large library is the
/// slow part, and a function from a plain document to bytes is what can be run
/// off the UI isolate.
Uint8List encodeDataExport(Map<String, Object?> document) {
  const encoder = JsonEncoder.withIndent('  ');

  return Uint8List.fromList(utf8.encode('${encoder.convert(document)}\n'));
}

/// One song, with exactly the fields the catalog holds.
///
/// The tags as the file carries them, trimmed: `albumArtist` is the file's own
/// tag, not the one the library works out across a record, which is what the
/// `albums` section carries.
Map<String, Object?> _song(String id, MusicEntry song) => {
  'id': id,
  'path': song.file.path,
  'title': song.title,
  'artist': song.artist,
  'albumArtist': trimmedOrNull(song.metadata.albumArtist),
  'album': song.album,
  'trackNumber': song.metadata.track,
  'trackTotal': song.metadata.trackTotal,
  'discNumber': song.metadata.disc,
  'year': song.metadata.year,
  'genres': song.genres,
  'durationMs': song.duration?.inMilliseconds,
};

/// The year every one of [songs] carries, or `null` when they differ or none
/// says.
int? _commonYear(List<MusicEntry> songs) {
  final years = {for (final song in songs) song.metadata.year};

  return years.length == 1 ? years.single : null;
}

Map<String, Object?> _playlist(
  Playlist playlist,
  String? Function(String path) idOf,
) => {
  'id': playlist.id,
  'name': playlist.name,
  'createdAt': _time(playlist.createdAt),
  'modifiedAt': _time(playlist.modifiedAt),
  'hasCustomCover': playlist.coverId != null,
  'entries': [
    for (final entry in playlist.entries)
      {
        'path': entry.path,
        'songId': idOf(entry.path),
        'title': entry.title,
        'artist': entry.artist,
        'album': entry.album,
        'durationMs': entry.duration?.inMilliseconds,
      },
  ],
};

/// The two auto playlists, whatever the *Show auto playlists* preference says:
/// it hides them on screen, it does not decide what the owner's data is.
List<Map<String, Object?>> _autoPlaylists(
  ExportSources sources,
  MusicCatalog catalog,
  List<String> Function(Iterable<MusicEntry> entries) idsOf,
) {
  final lately = favouritesLately(sources.history, catalog.byPath, sources.now);
  final allTime = allTimeFavourites(sources.history, catalog.byPath);

  return [
    {
      'kind': 'lately',
      'name': _latelyName,
      'fallback': lately.isFallback,
      'songs': idsOf(lately.songs),
    },
    {'kind': 'allTime', 'name': _allTimeName, 'songs': idsOf(allTime)},
  ];
}

List<Map<String, Object?>> _ranked(List<RankedPlays> lines) => [
  for (final line in lines)
    {'name': line.name, 'plays': line.plays, 'share': line.share},
];

/// [at] as an ISO-8601 UTC string.
String _time(DateTime at) => at.toUtc().toIso8601String();
