import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../autofill/data/atomic_write.dart';
import '../domain/play_history.dart';

/// [PlayHistoryStore] as one JSON document, beside the catalog.
///
/// The same shape as the catalog store, for the same reasons: the whole
/// history is read at once and never queried piecemeal, and it is written to a
/// temporary file and renamed over the real one so a history half-written
/// because the machine went down mid-track is not a history that will not
/// parse.
///
/// Unlike the catalog, the history cannot be built again: it is years of the
/// owner's listening. So it is handled as the playlists are — a document that
/// cannot be understood, by this version or because it was damaged, is
/// renamed to `play-history.json.bad-<yyyyMMddTHHmmss>` and an empty history
/// is read in its place, rather than the next play writing over it. What
/// could not be read is still there to be recovered by hand.
///
/// The document, `play-history.json`, version 2:
///
/// ```json
/// {
///   "version": 2,
///   "tracks": [
///     {
///       "path": "/library/a.flac",
///       "plays": 42,
///       "lastPlayedAt": "2026-10-17T22:05:01.250Z",   // ISO-8601, UTC
///       "recent": ["2026-09-30T08:00:00.000Z", "2026-10-17T22:05:01.250Z"]
///     }
///   ]
/// }
/// ```
///
/// `recent` holds the dates of the plays within [recentPlaysKept] of the
/// write, oldest first; every read and every write trims it to that window.
///
/// Version 1 is the same document without `recent`, as every release before
/// plays were dated wrote it. It is read as it stands — every track, its
/// count and its last play — with no dates, and written as version 2 by the
/// next write. The first time one is read, its bytes are also copied to
/// `play-history.json.v1`, once and never over an earlier copy: a release
/// from before version 2 reads the version-2 file as one it does not know
/// and starts over, and no release reads the copy: if the owner installs
/// one, they can restore their history by hand, by renaming the copy to
/// `play-history.json`. Any other version is set aside.
///
/// Within a document of a known version, a row that is not a play — no path,
/// no plays, no date it was last played, or a path already read — is stepped
/// over, and so is a date in `recent` that is not one: the rest of the
/// history is not given up for it. But the next write would leave what was
/// stepped over out for good, so the document is first *copied* to
/// `play-history.json.bad-<yyyyMMddTHHmmss>`, where it can still be recovered
/// by hand.
///
/// Every copy is made before the history is returned, and a copy that cannot
/// be made is an error, as a document that cannot be set aside is: returning
/// the history anyway would let the next write replace the only copy of what
/// it leaves out.
class JsonPlayHistoryStore implements PlayHistoryStore {
  /// Creates a store writing into [directory].
  ///
  /// [clock] is what the dates are trimmed against and what names the copy of
  /// an unreadable document, and is a parameter so a test can pin it.
  JsonPlayHistoryStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final Logger _log = Logger('stats');

  /// The document's version, written into it and checked on read.
  static const int documentVersion = 2;

  /// The version before plays were dated, which is still read.
  static const int _undatedVersion = 1;

  /// The file's name inside [directory].
  static const String fileName = 'play-history.json';

  /// Where the document is kept.
  final String directory;

  final DateTime Function() _clock;

  /// The document's path.
  String get path => p.join(directory, fileName);

  @override
  Future<PlayHistory> read() async {
    final file = File(path);
    if (!file.existsSync()) return PlayHistory.empty;

    // Only a document that was read and then not understood is set aside. A
    // file that cannot be opened — locked for a moment by an antivirus scan or
    // a sync client, say — is not a damaged one: its error goes up to the
    // caller rather than the history being set aside as if it were lost. So
    // the bytes are read and then decoded here, rather than read as text:
    // `readAsString` reports bytes that are not UTF-8 as a
    // [FileSystemException], the same as a file that could not be opened.
    final bytes = await file.readAsBytes();
    final _Reading reading;
    try {
      reading = _historyIn(jsonDecode(utf8.decode(bytes)));
    } on FormatException catch (error) {
      // Text that is not UTF-8, not JSON, or not a document of a version
      // this one reads.
      await _setAside(file, error);

      return PlayHistory.empty;
    }

    if (reading.version == _undatedVersion) _keepVersionOneCopy(bytes);
    if (reading.skipped > 0) _copyAside(bytes, reading.skipped);

    return reading.history.trimmedTo(_clock());
  }

  @override
  Future<void> write(PlayHistory history) async {
    await Directory(directory).create(recursive: true);

    final trimmed = history.trimmedTo(_clock());
    final document = jsonEncode({
      'version': documentVersion,
      'tracks': [
        for (final track in trimmed.tracks.values)
          {
            'path': track.path,
            'plays': track.plays,
            'lastPlayedAt': track.lastPlayedAt.toUtc().toIso8601String(),
            'recent': [
              for (final at in track.recent) at.toUtc().toIso8601String(),
            ],
          },
      ],
    });

    // Written beside the real file and renamed over it, which is atomic on
    // every filesystem this runs on.
    final temporary = File('$path.tmp');
    await temporary.writeAsString(document, flush: true);
    await temporary.rename(path);
  }

  /// Renames the document that could not be understood to a name that keeps
  /// it.
  ///
  /// Throws when it cannot be renamed. Carrying on would return an empty
  /// history with the document still in place, and the next play would
  /// replace it: the one thing setting it aside is for preventing.
  Future<void> _setAside(File file, Object error) async {
    final aside = '$path.bad-${_stamp(_clock())}';
    try {
      await file.rename(aside);
    } on FileSystemException catch (renameError) {
      _log.severe(
        'the play history could not be read, and could not be set aside',
        error,
      );
      throw FileSystemException(
        'Could not set the unreadable play history aside: '
        '${renameError.message}',
        path,
        renameError.osError,
      );
    }

    _log.severe(
      'the play history could not be read; kept as ${p.basename(aside)}',
      error,
    );
  }

  /// Copies a version-1 document to `play-history.json.v1`, unless a copy is
  /// already there.
  ///
  /// Throws when it cannot be copied: see the class's notes.
  void _keepVersionOneCopy(Uint8List bytes) {
    final copy = '$path.v1';
    if (File(copy).existsSync()) return;

    _copy(bytes, to: copy, what: 'the version-1 play history');
    _log.info('the version-1 play history is kept as ${p.basename(copy)}');
  }

  /// Copies a document some of which was stepped over to a name that keeps
  /// it, leaving the document where it is.
  ///
  /// Throws when it cannot be copied. Never copies over anything already
  /// there, which would be a document set aside before in the same second.
  void _copyAside(Uint8List bytes, int skipped) {
    final aside = '$path.bad-${_stamp(_clock())}';
    if (FileSystemEntity.typeSync(aside) != FileSystemEntityType.notFound) {
      _log.severe(
        'the play history had $skipped unreadable entries, and could not be '
        'copied aside: ${p.basename(aside)} is already there',
      );
      throw FileSystemException(
        'Could not copy the partly unreadable play history aside: '
        'the name is taken',
        aside,
      );
    }

    _copy(bytes, to: aside, what: 'the partly unreadable play history');
    _log.severe(
      'the play history had $skipped unreadable entries, which the next write '
      'leaves out; the whole document is kept as ${p.basename(aside)}',
    );
  }

  /// Writes [bytes] to [to] whole or not at all, throwing a
  /// [FileSystemException] that names [what] when it cannot.
  void _copy(Uint8List bytes, {required String to, required String what}) {
    try {
      replaceFileAtomically(to, bytes);
    } on FileSystemException catch (error) {
      _log.severe('$what could not be copied to ${p.basename(to)}', error);
      throw FileSystemException(
        'Could not copy $what aside: ${error.message}',
        to,
        error.osError,
      );
    }
  }

  static String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${at.year.toString().padLeft(4, '0')}${two(at.month)}'
        '${two(at.day)}T${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }

  /// The history in a decoded document, and how much of it was stepped over;
  /// throws a [FormatException] when it is not one this version reads.
  static _Reading _historyIn(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the document is not an object');
    }
    final version = decoded['version'];
    if (version is! int ||
        (version != documentVersion && version != _undatedVersion)) {
      throw FormatException('unknown version $version');
    }
    final tracks = decoded['tracks'];
    if (tracks is! List) {
      throw const FormatException('"tracks" is not a list');
    }

    var skipped = 0;
    void skip() => skipped++;

    final played = <String, TrackPlays>{};
    for (final track in tracks) {
      final record = track is Map<String, dynamic>
          ? _trackFrom(track, dated: version == documentVersion, skip: skip)
          : null;
      // A second row for a path already read is stepped over too: keeping
      // either one alone would lose the other's count.
      if (record == null || played.containsKey(record.path)) {
        skip();
        continue;
      }
      played[record.path] = record;
    }

    return _Reading(
      history: PlayHistory(tracks: played),
      version: version,
      skipped: skipped,
    );
  }

  /// One recorded track, or `null` where the entry is not one.
  ///
  /// [dated] is whether the document is one that kept dates: a version-1 row
  /// has none, whatever it holds. [skip] is told of each date stepped over.
  static TrackPlays? _trackFrom(
    Map<String, dynamic> track, {
    required bool dated,
    required void Function() skip,
  }) {
    final path = track['path'];
    final plays = track['plays'];
    final lastPlayedAt = DateTime.tryParse('${track['lastPlayedAt']}');

    if (path is! String || path.isEmpty) return null;
    if (plays is! int || plays <= 0) return null;
    if (lastPlayedAt == null) return null;

    return TrackPlays(
      path: path,
      plays: plays,
      lastPlayedAt: lastPlayedAt,
      recent: dated ? _datesIn(track['recent'], skip: skip) : const [],
    );
  }

  /// The dates in a row's `recent`, in UTC and oldest first. Those that are
  /// not dates are left out, and [skip] is told of each.
  static List<DateTime> _datesIn(
    Object? recent, {
    required void Function() skip,
  }) {
    if (recent == null) return const [];
    if (recent is! List) {
      skip();

      return const [];
    }

    final dates = <DateTime>[];
    for (final at in recent) {
      final parsed = at is String ? DateTime.tryParse(at) : null;
      if (parsed == null) {
        skip();
      } else {
        dates.add(parsed.toUtc());
      }
    }

    return List.unmodifiable(dates..sort());
  }
}

/// What reading a document found.
class _Reading {
  const _Reading({
    required this.history,
    required this.version,
    required this.skipped,
  });

  /// The history in it.
  final PlayHistory history;

  /// The version it was written as.
  final int version;

  /// How many rows and dates in it were stepped over.
  final int skipped;
}
