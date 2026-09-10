import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import '../../../core/failures/failure.dart';
import '../domain/library_scan.dart';
import '../domain/music_catalog.dart';
import '../domain/music_entry.dart';
import '../domain/music_grouping.dart';
import 'scan_worker.dart';

/// [LibraryScanner] running [scanFolders] on an isolate of its own.
///
/// On an isolate because of what a scan is: a walk of every path under the
/// library folders and a parse of every audio file among them, all of it
/// synchronous file IO and CPU. Run on the interface's isolate it would hold
/// the frame for as long as it took — minutes, on a large library — and no
/// amount of awaiting inside it would help, because none of the work is
/// asynchronous.
///
/// Nothing but plain objects crosses the boundary: paths in, progress and
/// entries out.
class IsolateLibraryScanner implements LibraryScanner {
  /// Creates a scanner.
  const IsolateLibraryScanner();

  static final Logger _log = Logger('library');

  @override
  Stream<ScanEvent> scan({
    required List<String> folders,
    required MusicCatalog previous,
    required String coverDirectory,
    DateTime? unchangedSince,
  }) {
    final events = StreamController<ScanEvent>();
    final messages = ReceivePort();
    final errors = ReceivePort();
    Isolate? isolate;

    /// Lets go of the isolate and the two ports it answers on.
    ///
    /// Kept apart from closing [events], and the separation is the whole of
    /// why this exists: this also runs when the *subscriber* walks away, and
    /// there the controller must not be closed. Closing a controller waits for
    /// its done event to be delivered, and a subscription being cancelled is
    /// precisely the thing that stops one ever being — so a cancel handler
    /// that awaited it waited forever, and `cancel` never answered.
    ///
    /// What that cost is a scan controller that cancels the previous
    /// subscription on its way into the next scan: the first scan of a session
    /// worked, and every one after it stopped on that line with the strip
    /// saying "scanning" and no scan running. Adding a folder, removing one,
    /// or pressing the button reported a scan that never finished and never
    /// found anything.
    void release() {
      messages.close();
      errors.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    /// The scan is over: let go, and tell whoever is listening.
    Future<void> close() async {
      release();
      await events.close();
    }

    messages.listen((message) {
      switch (message) {
        case ScanProgress():
          events.add(ScanAdvanced(message));
        case ScanOutcome():
          events.add(
            ScanCompleted(
              catalog: MusicCatalog(
                // Applied here rather than in the worker so that a catalog
                // read back from disk and one just scanned go through exactly
                // the same derivation — one place decides whose record a track
                // is on, and it is not duplicated across the boundary.
                entries: albumArtistsAcross(message.entries),
                scannedAt: DateTime.now(),
              ),
              report: message.report,
            ),
          );
          unawaited(close());
      }
    });

    errors.listen((error) {
      // The isolate sends [error, stackTrace] as a two-element list. Whatever
      // it was, the scan produced no catalog, and the screen is owed that fact
      // rather than a progress bar that stopped moving.
      _log.severe('the library scan failed', error);
      events.add(const ScanFailed(UnexpectedFailure()));
      unawaited(close());
    });

    events.onCancel = release;

    unawaited(
      Isolate.spawn(
            _run,
            _ScanRequest(
              folders: folders,
              previous: previous.entries,
              coverDirectory: coverDirectory,
              unchangedSince: unchangedSince,
              reply: messages.sendPort,
            ),
            onError: errors.sendPort,
            errorsAreFatal: true,
            debugName: 'orpheus-scan',
          )
          // Typed as void deliberately. A spawn that failed has no isolate to
          // answer with, and an earlier version satisfied the `Future<Isolate>`
          // this chain would otherwise have by asserting the one it had just
          // failed to get — which threw a second, unhandled error out of the
          // handler for the first.
          .then<void>((spawned) => isolate = spawned)
          .catchError((Object error) {
            _log.severe('the library scan could not start', error);
            events.add(const ScanFailed(UnexpectedFailure()));
            unawaited(close());
          }),
    );

    return events.stream;
  }
}

/// What the isolate is asked to do.
class _ScanRequest {
  const _ScanRequest({
    required this.folders,
    required this.previous,
    required this.coverDirectory,
    required this.reply,
    this.unchangedSince,
  });

  final List<String> folders;
  final List<MusicEntry> previous;
  final String coverDirectory;
  final DateTime? unchangedSince;
  final SendPort reply;
}

/// The isolate's entry point.
void _run(_ScanRequest request) {
  final outcome = scanFolders(
    folders: request.folders,
    previous: request.previous,
    coverDirectory: request.coverDirectory,
    unchangedSince: request.unchangedSince,
    onProgress: request.reply.send,
  );

  request.reply.send(outcome);
}
