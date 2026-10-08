import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/audio_extensions.dart';
import '../domain/audio_file.dart';
import '../domain/library_scan.dart';
import '../domain/music_entry.dart';
import '../domain/track_metadata.dart';
import 'file_cover_store.dart';
import 'tag_reading.dart';

/// What one run of [scanFolders] produced.
class ScanOutcome {
  /// Creates an outcome.
  const ScanOutcome({
    required this.entries,
    required this.report,
    required this.startedAt,
  });

  /// The library, one entry per file found.
  ///
  /// Not yet told whose record each track is on: `albumArtistsAcross` is
  /// applied where the catalog is assembled, so that a catalog read back from
  /// disk and one just scanned go through exactly the same derivation.
  final List<MusicEntry> entries;

  /// What changed, and what could not be read.
  final ScanReport report;

  /// When the walk began, which is the moment the catalog describes.
  ///
  /// The start rather than the end, because it is what the next cheap walk
  /// measures folders against: a folder changed while this scan was running —
  /// after the walk had passed it, before the scan finished — is newer than
  /// the start and older than the end, and measuring against the end would
  /// let the next launch take it on trust and keep the tags this scan read
  /// before the change.
  final DateTime startedAt;
}

/// Walks [folders] and reads the tags of every audio file under them.
///
/// Synchronous and self-contained on purpose. It is the whole of the expensive
/// half of this application — a walk of tens of thousands of paths and a parse
/// of every one of them — and it is written so that it can run on an isolate
/// with nothing but strings and plain objects crossing the boundary. That is
/// also what makes it directly testable against a temporary directory, which
/// is where every rule below is actually checked.
///
/// [previous] is the last catalog. A file still on disk at the same size and
/// the same timestamp is carried over from it rather than re-parsed, which is
/// what makes re-scanning an unchanged library cheap enough to do at every
/// launch.
///
/// [onProgress] is called as the walk and the read advance; it is called often
/// but not per file — see [progressInterval].
///
/// [unchangedSince] turns on the cheap walk, and is the moment the last scan
/// began. A directory whose own timestamp is older than that — by more than
/// [timestampSlack], for the file systems that round it — has had nothing
/// added to it, removed from it or renamed inside it since, so the files in it
/// are the files the last scan recorded, and their sizes and timestamps are
/// taken from [previous] instead of from the disk. What that saves is one
/// `stat` per file — on a library of eleven thousand tracks, eleven thousand
/// system calls, which on a phone's storage is most of what a re-scan costs.
///
/// What it gives up is a file rewritten *in place*: that changes the file's
/// own timestamp and not its folder's, so the cheap walk carries the old tags
/// over. Anything that adds, deletes or renames is still seen, and so is a
/// tagger that writes to a temporary file and renames over the original, which
/// is what most of them do. Pass `null` — as the scan the owner asks for by
/// hand does — and every file is stat'ed as before.
ScanOutcome scanFolders({
  required List<String> folders,
  required List<MusicEntry> previous,
  required String coverDirectory,
  void Function(ScanProgress progress)? onProgress,
  DateTime? unchangedSince,
}) {
  final startedAt = DateTime.now();
  final covers = FileCoverStore(coverDirectory);
  final known = {for (final entry in previous) entry.file.path: entry};

  final found = <AudioFile>[];
  final unreachable = <String>[];
  final unreadable = <String>[];

  // Shared across every registered folder, not per folder. Two folders where
  // one contains the other are a real configuration — an owner adds their
  // whole music drive and then a favourite record inside it — and a set that
  // started fresh for each of them would collect that record's tracks twice.
  final visited = <String>{};

  // Two passes, and the walk is the first of them, because a scan that
  // reported "read 40 of 40" and then found four hundred more would be a
  // progress bar that lies. The walk is fast — it stats files and parses
  // nothing — so the wait before the real count appears is short.
  for (final folder in folders) {
    final directory = Directory(folder);
    if (!directory.existsSync()) {
      unreachable.add(folder);
      continue;
    }

    // A registered folder that is there and cannot be listed is as unreachable
    // as one that is not there at all, and is reported the same way. Stepped
    // over silently, it read as a folder with nothing in it: every track the
    // catalog held from it was counted as removed, and the folders screen never
    // offered the access that would have let it be read.
    final listed = _walk(
      directory,
      found: found,
      visited: visited,
      known: known,
      unchangedSince: unchangedSince,
      onProgress: onProgress == null
          ? null
          : () => onProgress(
              ScanProgress(filesFound: found.length, folder: folder),
            ),
    );
    if (!listed) unreachable.add(folder);
  }

  // Deterministic order, so two scans of the same library produce the same
  // catalog document: `listSync` answers in whatever order the filesystem
  // holds, which is not stable between machines or even between runs.
  found.sort((a, b) => a.path.compareTo(b.path));

  // What is actually on disk this time, so that "removed" can be counted as
  // the question it is — which of the paths the catalog held are no longer
  // there. Counting it as `known.length - reused` instead made every file that
  // had merely *changed* count as one removed and one added, so re-tagging a
  // track reported a removal that never happened.
  final present = {for (final file in found) file.path};

  final entries = <MusicEntry>[];
  final sidecars = <String, String?>{};
  var reused = 0;
  var added = 0;

  for (final file in found) {
    if (onProgress != null && entries.length % progressInterval == 0) {
      onProgress(
        ScanProgress(
          filesFound: found.length,
          filesRead: entries.length,
          folder: file.directory,
          walking: false,
        ),
      );
    }

    final carried = known[file.path];
    if (carried != null &&
        carried.file.sizeInBytes == file.sizeInBytes &&
        _sameMillisecond(carried.file.modifiedAt, file.modifiedAt)) {
      entries.add(MusicEntry(file: file, metadata: carried.metadata));
      reused++;
      continue;
    }

    added++;
    entries.add(
      _read(
        file,
        covers: covers,
        sidecars: sidecars,
        onUnreadable: unreadable.add,
      ),
    );
  }

  onProgress?.call(
    ScanProgress(
      filesFound: found.length,
      filesRead: entries.length,
      walking: false,
    ),
  );

  return ScanOutcome(
    startedAt: startedAt,
    entries: entries,
    report: ScanReport(
      tracks: entries.length,
      added: added,
      reused: reused,
      removed: known.keys.where((path) => !present.contains(path)).length,
      unreadable: unreadable,
      unreachableFolders: unreachable,
    ),
  );
}

/// Whether [a] and [b] are the same moment to the millisecond.
///
/// The catalog document stores a file's timestamp in milliseconds, and the
/// file system reports it in microseconds. Compared exactly, a catalog read
/// back from disk matched almost none of the files it described, so the first
/// full scan of every launch re-read the tags of the whole library and
/// reported every track in it as added.
bool _sameMillisecond(DateTime a, DateTime b) =>
    a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;

/// How far a folder's timestamp may lag a change made inside it.
///
/// FAT, which is what most memory cards and pen drives are formatted with,
/// keeps a timestamp to the nearest two seconds, rounded down. A folder changed
/// a second after a scan began can therefore read as older than the scan, and
/// the cheap walk would take it on trust; only a folder older than this margin
/// as well is treated as settled.
const Duration timestampSlack = Duration(seconds: 2);

/// How many files pass between progress reports.
///
/// A report per file would be a message across the isolate boundary per file
/// and a rebuild of the strip per file, which on a fast disk is thousands a
/// second — the reporting would cost more than the parsing.
const int progressInterval = 25;

/// Reads one file's tags, storing whatever picture it leads to.
MusicEntry _read(
  AudioFile file, {
  required FileCoverStore covers,
  required Map<String, String?> sidecars,
  required void Function(String path) onUnreadable,
}) {
  TrackMetadata metadata;
  String? coverId;

  try {
    final tags = readTags(File(file.path));
    metadata = tags.metadata;
    if (tags.picture case final picture? when picture.isNotEmpty) {
      coverId = covers.putSync(picture);
    }
  } on Object {
    // Deliberately broad, and deliberately not fatal. A file whose tags will
    // not parse is very often a file that plays perfectly well — an unusual
    // encoder, a truncated tag, a format this reader has no parser for — so it
    // joins the library as an untitled track and its path is reported, rather
    // than being dropped from a library the owner can see it in.
    onUnreadable(file.path);
    metadata = TrackMetadata.empty;
  }

  // A record with no embedded art but a `cover.jpg` beside it is the other
  // half of how libraries actually store sleeves. Looked up once per folder:
  // a directory of twelve tracks would otherwise be twelve listings of the
  // same directory.
  coverId ??= _sidecarCover(file.directory, covers: covers, cache: sidecars);

  return MusicEntry(
    file: file,
    metadata: coverId == null ? metadata : metadata.copyWith(coverId: coverId),
  );
}

/// The id of the sidecar cover in [directory], or `null` where there is none.
String? _sidecarCover(
  String directory, {
  required FileCoverStore covers,
  required Map<String, String?> cache,
}) {
  if (cache.containsKey(directory)) return cache[directory];

  String? found;
  try {
    final candidates = <String, String>{};
    for (final entity in Directory(directory).listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (isCoverPath(entity.path)) {
        candidates[p.basenameWithoutExtension(entity.path).toLowerCase()] =
            entity.path;
      }
    }

    for (final name in coverBaseNames) {
      final path = candidates[name];
      if (path == null) continue;

      // Only a picture with bytes in it settles the folder. A zero-length
      // `cover.jpg` — which is what a failed download leaves behind — is not a
      // sleeve, and stopping at it would hide the `folder.jpg` beside it.
      final bytes = File(path).readAsBytesSync();
      if (bytes.isEmpty) continue;

      found = covers.putSync(bytes);
      break;
    }
  } on Object {
    // A folder that cannot be listed, or a picture that cannot be read, is a
    // record without a sleeve. Nothing else about it changes.
    found = null;
  }

  cache[directory] = found;

  return found;
}

/// Adds every audio file under [directory] to [found], depth first.
///
/// Answers whether [directory] itself could be listed — or had already been,
/// through another registered folder. A folder below it that cannot be listed
/// is stepped over; only the caller knows whether the top one not opening is
/// worth reporting.
///
/// Written out rather than `listSync(recursive: true)` for two reasons. One
/// unreadable folder inside a library makes the recursive call throw and
/// abandon the rest of the walk, where this steps over it and carries on. And
/// progress can be reported while the walk runs, which on a library of tens of
/// thousands of files is the difference between a strip that moves and one
/// that sits still for a minute.
bool _walk(
  Directory directory, {
  required List<AudioFile> found,
  required Set<String> visited,
  required Map<String, MusicEntry> known,
  DateTime? unchangedSince,
  void Function()? onProgress,
}) {
  // Symbolic links are not followed, but a library folder can still be reached
  // twice — two registered folders where one contains the other. The resolved
  // path is what makes that one visit rather than two, and the same track one
  // entry rather than two identical ones.
  final seen = visited;

  final String resolved;
  try {
    resolved = directory.resolveSymbolicLinksSync();
  } on Object {
    return false;
  }
  if (!seen.add(resolved)) return true;

  final List<FileSystemEntity> children;
  try {
    children = directory.listSync(followLinks: false);
  } on Object {
    // A folder the process may not read is a folder with nothing in it, as far
    // as the rest of the walk is concerned.
    return false;
  }

  // Whether the files here can be taken from the last catalog rather than
  // stat'ed one by one — see [scanFolders]. The folder's own timestamp is one
  // system call; the files in it are one each.
  var settled = false;
  if (unchangedSince != null) {
    try {
      settled = directory.statSync().modified.isBefore(
        unchangedSince.subtract(timestampSlack),
      );
    } on Object {
      settled = false;
    }
  }

  for (final child in children) {
    if (child is Directory) {
      // Hidden directories are skipped whole: `.git`, `.Trash-1000` and
      // `.thumbnails` hold nothing anybody wants in their library, and walking
      // them is the bulk of the cost of scanning a home folder.
      if (p.basename(child.path).startsWith('.')) continue;

      _walk(
        child,
        found: found,
        visited: seen,
        known: known,
        unchangedSince: unchangedSince,
        onProgress: onProgress,
      );
      continue;
    }

    if (child is! File || !isAudioPath(child.path)) continue;

    // A settled folder answers from the last catalog. A file in one that the
    // catalog does not know is still stat'ed: it is a file the last scan did
    // not see, whatever the folder's timestamp says.
    if (settled) {
      if (known[child.path] case final carried?) {
        found.add(carried.file);
        if (found.length % progressInterval == 0) onProgress?.call();
        continue;
      }
    }

    try {
      final stat = child.statSync();
      found.add(
        AudioFile(
          path: child.path,
          sizeInBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    } on Object {
      continue;
    }

    if (found.length % progressInterval == 0) onProgress?.call();
  }

  return true;
}
