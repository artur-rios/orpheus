import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/failures/failure.dart';
import '../domain/library_access.dart';
import '../domain/library_scan.dart';
import '../domain/music_catalog.dart';

/// Where the scan is.
class ScanState {
  /// Creates a state.
  const ScanState({
    this.progress,
    this.report,
    this.failure,
    this.isRunning = false,
  });

  /// Nothing is scanning and nothing has been reported.
  static const ScanState idle = ScanState();

  /// How far the running scan has got, or `null` when none is running.
  final ScanProgress? progress;

  /// What the last finished scan found, or `null` before one has finished.
  ///
  /// Kept after the scan ends so the library screen can say what changed and
  /// name the files it could not read — a report that vanished with the
  /// progress bar would be a report nobody saw.
  final ScanReport? report;

  /// Why the last scan could not run, or `null`.
  final Failure? failure;

  /// Whether a scan is running now.
  final bool isRunning;

  /// Whether anything is worth showing above the playback bar.
  bool get isVisible => isRunning || failure != null;
}

/// Runs library scans.
///
/// One at a time: a second scan started while the first is running would have
/// two isolates walking the same folders and two catalogs racing to be written.
/// A request made while one is running is dropped, and the running scan is what
/// the owner sees.
class ScanController extends Notifier<ScanState> {
  static final Logger _log = Logger('library');

  StreamSubscription<ScanEvent>? _events;

  @override
  ScanState build() {
    ref.onDispose(() => unawaited(_events?.cancel()));

    return ScanState.idle;
  }

  /// Scans every registered folder.
  ///
  /// Answers when the scan has *finished*, not when it has started, so that a
  /// caller which wants to do something with the library afterwards — the
  /// startup sequence, the folder screen's own button — can await it.
  ///
  /// [askForAccess] is what the platform's permission dialog hangs off. On by
  /// default, including for the scan that runs at startup — an owner who has
  /// registered a folder has already said they want it read, and on Android
  /// there is no way to read it without asking. It is turned off in tests, and
  /// available to be turned off wherever a scan must not put a dialog in front
  /// of anyone.
  ///
  /// [quick] asks for the cheap walk, where a folder untouched since the last
  /// scan is taken from the catalog rather than stat'ed file by file. It is on
  /// for the scan at startup, which runs whether or not anything has changed
  /// and is the one an owner waits through every launch; it is off for the
  /// scan they ask for by hand, which is exactly what they press when a file
  /// has been re-tagged underneath the application.
  ///
  /// The order matters and is deliberate: a library with no folders registered
  /// returns before the question is asked, so a fresh install does not open on
  /// a permission dialog for files it has not been pointed at.
  Future<void> scan({bool askForAccess = true, bool quick = false}) async {
    if (state.isRunning) return;

    final folders = ref.read(libraryFoldersControllerProvider);
    if (folders.isEmpty) {
      // Nothing registered is not a failure and not a scan. The library screen
      // already says what to do about it, and clearing any previous report
      // here is what stops a stale one hanging around after the last folder is
      // removed.
      state = ScanState.idle;
      await _apply(null);
      return;
    }

    if (askForAccess) {
      final decision = await ref
          .read(libraryAccessControllerProvider.notifier)
          .ensure();
      if (!decision.isGranted) {
        state = ScanState(
          failure: StoragePermissionDenied(
            permanently: decision == LibraryAccessDecision.deniedPermanently,
          ),
        );
        return;
      }
    }

    state = const ScanState(isRunning: true, progress: ScanProgress());

    final previous = await ref.read(musicLibraryControllerProvider.future);
    final finished = Completer<void>();

    await _events?.cancel();
    _events = ref
        .read(libraryScannerProvider)
        .scan(
          folders: folders,
          previous: previous,
          coverDirectory: ref.read(appDirectoriesProvider).covers,
          unchangedSince: quick ? previous.scannedAt : null,
        )
        .listen(
          (event) async {
            switch (event) {
              case ScanAdvanced(:final progress):
                state = ScanState(isRunning: true, progress: progress);

              case ScanCompleted(:final catalog, :final report):
                await _apply(catalog, report: report);
                state = ScanState(report: report);
                if (!finished.isCompleted) finished.complete();

              case ScanFailed(:final failure):
                state = ScanState(failure: failure);
                if (!finished.isCompleted) finished.complete();
            }
          },
          onDone: () {
            // A stream that ended without completing is a scan whose isolate
            // died quietly. The state is left as it stands — whatever the last
            // event said — but the caller must not be left awaiting forever.
            if (!finished.isCompleted) finished.complete();
          },
        );

    return finished.future;
  }

  /// Clears the report of the last scan, once the owner has read it.
  void acknowledge() => state = ScanState.idle;

  /// Writes [catalog] and puts it on screen.
  ///
  /// `null` empties the library, which is what removing the last folder means.
  ///
  /// [report] is what the scan found, and what decides whether the document is
  /// rewritten at all. A scan that added nothing and removed nothing produced
  /// a catalog holding exactly the entries the stored one already holds — the
  /// carried-over metadata came from that document in the first place — so
  /// writing it back would encode several megabytes of JSON and push it at the
  /// disk to produce the file that is already there. On a library of eleven
  /// thousand tracks that is the single most expensive thing a launch does,
  /// and for an unchanged library it buys nothing.
  ///
  /// The library is still replaced on screen, because the catalog carries the
  /// time of the scan and the folder screen shows it: skipping that too would
  /// save a re-grouping worth a fraction of the write, and would leave the
  /// screen saying the library was last scanned some other day.
  Future<void> _apply(MusicCatalog? catalog, {ScanReport? report}) async {
    final library = ref.read(musicLibraryControllerProvider.notifier);

    if (catalog == null) {
      await library.clear();
      return;
    }

    library.replaceWith(catalog);

    if (report != null && report.added == 0 && report.removed == 0) return;

    try {
      await ref.read(catalogStoreProvider).write(catalog);
    } on Object catch (error) {
      // A catalog that could not be written is a scan the next launch has to
      // repeat. The library is on screen either way, which is what the owner
      // asked for.
      _log.warning('the catalog could not be written', error);
    }
  }
}
