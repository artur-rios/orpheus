import '../../../core/failures/failure.dart';
import 'music_catalog.dart';

/// How far a scan has got.
///
/// Two counts and a name, because that is what a progress report can honestly
/// carry: a scan discovers files as it walks, so the total is not known until
/// the walk is done, and a percentage computed against a total that is still
/// growing is a bar that goes backwards.
class ScanProgress {
  /// Creates a report.
  const ScanProgress({
    this.filesFound = 0,
    this.filesRead = 0,
    this.folder,
    this.walking = true,
  });

  /// How many audio files the walk has found so far.
  final int filesFound;

  /// How many of them have had their tags read.
  final int filesRead;

  /// The folder being walked or read from, for the strip to name.
  final String? folder;

  /// Whether the walk is still discovering files.
  ///
  /// While it is, [filesFound] is a floor rather than a total, and the strip
  /// shows an indeterminate bar. Once the walk is done the two counts are a
  /// real fraction.
  final bool walking;

  /// How far through the read this is, 0 to 1, or `null` while the total is
  /// still unknown.
  double? get fraction {
    if (walking || filesFound == 0) return null;

    return (filesRead / filesFound).clamp(0.0, 1.0);
  }

  /// A copy with the given changes.
  ScanProgress copyWith({
    int? filesFound,
    int? filesRead,
    String? folder,
    bool? walking,
  }) => ScanProgress(
    filesFound: filesFound ?? this.filesFound,
    filesRead: filesRead ?? this.filesRead,
    folder: folder ?? this.folder,
    walking: walking ?? this.walking,
  );
}

/// What a finished scan found.
class ScanReport {
  /// Creates a report.
  const ScanReport({
    required this.tracks,
    required this.added,
    required this.removed,
    required this.reused,
    this.unreadable = const [],
    this.unreachableFolders = const [],
  });

  /// How many tracks the library holds now.
  final int tracks;

  /// How many of them this scan read for the first time.
  final int added;

  /// How many the previous catalog held that are no longer on disk.
  final int removed;

  /// How many were carried over from the previous catalog untouched, because
  /// neither their size nor their timestamp had changed.
  final int reused;

  /// The files whose tags could not be parsed, by path.
  ///
  /// Named rather than counted: "eleven files could not be read" tells an
  /// owner nothing about which of their files to go and look at. They are
  /// still in the library — a file with unreadable tags is a file that very
  /// often still plays — and they are shown as untitled, which is what a file
  /// with no tags is.
  final List<String> unreadable;

  /// The registered folders that were not there to be walked.
  final List<String> unreachableFolders;
}

/// What a scan reports as it runs.
sealed class ScanEvent {
  /// Creates an event.
  const ScanEvent();
}

/// The scan is running.
class ScanAdvanced extends ScanEvent {
  /// Creates the event carrying [progress].
  const ScanAdvanced(this.progress);

  /// How far it has got.
  final ScanProgress progress;
}

/// The scan finished, and this is what it found.
class ScanCompleted extends ScanEvent {
  /// Creates the event.
  const ScanCompleted({required this.catalog, required this.report});

  /// The library as it now stands.
  final MusicCatalog catalog;

  /// What changed, and what could not be read.
  final ScanReport report;
}

/// The scan could not run at all.
///
/// Distinct from a folder that was unreachable, which the scan steps over and
/// reports at the end: this is the scan itself failing — the isolate refusing
/// to start, the cover directory refusing to be written — where there is no
/// catalog to hand back.
class ScanFailed extends ScanEvent {
  /// Creates the event carrying [failure].
  const ScanFailed(this.failure);

  /// Why it could not run.
  final Failure failure;
}

/// Builds a catalog from the folders the owner registered.
///
/// Behind an interface for the usual reason and one more: the implementation
/// runs the walk and the tag parsing on another isolate, and a test that had
/// to spawn one to check what the library screen does with a report would be a
/// test of the isolate rather than of the screen.
abstract interface class LibraryScanner {
  /// Walks [folders], reads what has changed, and reports as it goes.
  ///
  /// [previous] is what the last scan found. Anything in it whose file is
  /// still on disk at the same size and timestamp is carried over rather than
  /// re-read, which is what makes a re-scan of an unchanged library fast
  /// enough to run at every startup.
  ///
  /// [coverDirectory] is where extracted pictures are written.
  Stream<ScanEvent> scan({
    required List<String> folders,
    required MusicCatalog previous,
    required String coverDirectory,
  });
}
