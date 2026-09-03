import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../domain/play_history.dart';

/// [PlayHistoryStore] as one JSON document, beside the catalog.
///
/// The same shape as the catalog store, for the same reasons: the whole
/// history is read at once and never queried piecemeal, and it is written to a
/// temporary file and renamed over the real one so a history half-written
/// because the machine went down mid-track is not a history that will not
/// parse.
///
/// Losing this file loses statistics and nothing else. That is why a document
/// that cannot be read is reported and stepped over rather than treated as a
/// failure the owner has to answer: the music still plays, and the alternative
/// is an application that will not start because of a counter.
class JsonPlayHistoryStore implements PlayHistoryStore {
  /// Creates a store writing into [directory].
  JsonPlayHistoryStore(this.directory);

  static final Logger _log = Logger('stats');

  /// The document's version, written into it and checked on read.
  static const int documentVersion = 1;

  /// The file's name inside [directory].
  static const String fileName = 'play-history.json';

  /// Where the document is kept.
  final String directory;

  /// The document's path.
  String get path => p.join(directory, fileName);

  @override
  Future<PlayHistory> read() async {
    final file = File(path);
    if (!file.existsSync()) return PlayHistory.empty;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return PlayHistory.empty;
      if (decoded['version'] != documentVersion) {
        _log.info('the play history was written by another version; starting over');

        return PlayHistory.empty;
      }

      final tracks = decoded['tracks'];
      if (tracks is! List) return PlayHistory.empty;

      final played = <String, TrackPlays>{};
      for (final track in tracks) {
        if (track is! Map<String, dynamic>) continue;

        final record = _trackFrom(track);
        if (record != null) played[record.path] = record;
      }

      return PlayHistory(tracks: played);
    } on Object catch (error) {
      // A history that will not parse is a history that is gone. Said once,
      // and the counting starts again — which costs the owner a number and
      // nothing they can hear.
      _log.warning('the play history could not be read; starting over', error);

      return PlayHistory.empty;
    }
  }

  @override
  Future<void> write(PlayHistory history) async {
    await Directory(directory).create(recursive: true);

    final document = jsonEncode({
      'version': documentVersion,
      'tracks': [
        for (final track in history.tracks.values)
          {
            'path': track.path,
            'plays': track.plays,
            'lastPlayedAt': track.lastPlayedAt.toUtc().toIso8601String(),
          },
      ],
    });

    // Written beside the real file and renamed over it, which is atomic on
    // every filesystem this runs on.
    final temporary = File('$path.tmp');
    await temporary.writeAsString(document, flush: true);
    await temporary.rename(path);
  }

  /// One recorded track, or `null` where the entry is not one.
  TrackPlays? _trackFrom(Map<String, dynamic> track) {
    final path = track['path'];
    final plays = track['plays'];
    final lastPlayedAt = DateTime.tryParse('${track['lastPlayedAt']}');

    if (path is! String || path.isEmpty) return null;
    if (plays is! int || plays <= 0) return null;
    if (lastPlayedAt == null) return null;

    return TrackPlays(path: path, plays: plays, lastPlayedAt: lastPlayedAt);
  }
}
