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
  const ScanOutcome({required this.entries, required this.report});

  /// The library, one entry per file found.
  ///
  /// Not yet told whose record each track is on: `albumArtistsAcross` is
  /// applied where the catalog is assembled, so that a catalog read back from
  /// disk and one just scanned go through exactly the same derivation.
  final List<MusicEntry> entries;

  /// What changed, and what could not be read.
  final ScanReport report;
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
/// ran. A directory whose own timestamp is older than that has had nothing
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
  /// How many files pass between progress reports.
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

    _walk(
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
  }

  // Deterministic order, so two scans of the same library produce the same
  // catalog document: `listSync` answers in whatever order the filesystem
  // holds, which is not stable between machines or even between runs.
  found.sort((a, b) => a.path.compareTo(b.path));

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
        carried.file.modifiedAt == file.modifiedAt) {
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
    entries: entries,
    report: ScanReport(
      tracks: entries.length,
      added: added,
      reused: reused,
      removed: known.length - reused,
      unreadable: unreadable,
      unreachableFolders: unreachable,
    ),
  );
}

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

      final bytes = File(path).readAsBytesSync();
      if (bytes.isNotEmpty) found = covers.putSync(bytes);
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
/// Written out rather than `listSync(recursive: true)` for two reasons. One
/// unreadable folder inside a library makes the recursive call throw and
/// abandon the rest of the walk, where this steps over it and carries on. And
/// progress can be reported while the walk runs, which on a library of tens of
/// thousands of files is the difference between a strip that moves and one
/// that sits still for a minute.
void _walk(
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
    return;
  }
  if (!seen.add(resolved)) return;

  final List<FileSystemEntity> children;
  try {
    children = directory.listSync(followLinks: false);
  } on Object {
    // A folder the process may not read is a folder with nothing in it, as far
    // as the rest of the walk is concerned.
    return;
  }

  // Whether the files here can be taken from the last catalog rather than
  // stat'ed one by one — see [scanFolders]. The folder's own timestamp is one
  // system call; the files in it are one each.
  var settled = false;
  if (unchangedSince != null) {
    try {
      settled = directory.statSync().modified.isBefore(unchangedSince);
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
}
