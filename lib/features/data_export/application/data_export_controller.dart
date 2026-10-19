import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../domain/data_export.dart';
import 'export_sources.dart';

/// How an export ended.
enum DataExportOutcome {
  /// The file was saved, with everything in it.
  saved,

  /// The file was saved, but a source could not be read, or the library is
  /// being rebuilt, so the document says a section is empty for that reason.
  savedWithProblems,

  /// The owner closed the save dialog; nothing was written.
  cancelled,

  /// The library could not be read, so there was nothing meaningful to export
  /// and nothing was offered.
  libraryFailed,

  /// The file could not be saved.
  failed,
}

/// The outcome of one export, and where the file went.
class DataExportResult {
  /// Creates a result.
  const DataExportResult(this.outcome, {this.path});

  /// How it ended.
  final DataExportOutcome outcome;

  /// Where the file was saved, when it was and the platform has a path to
  /// tell: `null` for every other outcome, and for a place with no path.
  final String? path;
}

/// Runs a computation somewhere other than the caller: the shape of
/// [Isolate.run], which is what stands in for it in a test.
typedef OffIsolateRunner = Future<R> Function<R>(
  FutureOr<R> Function() computation,
);

/// [sources] as the encoded document, built and encoded off the UI isolate.
///
/// A 20 000-song library is megabytes of JSON, and building and encoding it
/// is long enough to freeze the window if it ran there. The sources go across
/// as they are, plain values every one, and the bytes come back.
///
/// [run] is a parameter so that a test can see the work handed over without
/// starting an isolate, which a widget test's fake time would never hear back
/// from.
///
/// A top-level function, not a closure inside a provider: a closure sent to
/// an isolate takes everything it can see with it, and inside a provider that
/// includes the `Ref`, which cannot be sent.
Future<Uint8List> encodeOffTheUiIsolate(
  ExportSources sources, {
  OffIsolateRunner run = Isolate.run,
}) => run(() => encodeDataExport(buildDataExport(sources)));

/// Exports the owner's data to a file they choose.
///
/// State is whether an export is running, which is what the Preferences
/// disable their entry on. One at a time: asking for another while one runs
/// answers with the one already under way rather than offering a second save
/// dialog over the first.
///
/// **Only reads.** Everything here is read from the controllers that hold it,
/// and the only thing written is the file the owner picked.
class DataExportController extends Notifier<bool> {
  static final Logger _log = Logger('data-export');

  Future<DataExportResult>? _running;

  @override
  bool build() => false;

  /// Gathers the owner's data, builds the document and offers it to the save
  /// dialog.
  ///
  /// Never throws: how it went is the [DataExportResult].
  Future<DataExportResult> export() {
    final running = _running;
    if (running != null) return running;

    state = true;
    final started = _export().whenComplete(() {
      _running = null;
      state = false;
    });

    return _running = started;
  }

  Future<DataExportResult> _export() async {
    try {
      final sources = await gatherExportSources(ref);
      if (sources == null) {
        return const DataExportResult(DataExportOutcome.libraryFailed);
      }
      final now = sources.now;
      final bytes = await ref.read(dataExportEncoderProvider)(sources);

      final saved = await ref
          .read(fileSaverProvider)
          .save(suggestedName: _fileName(now), bytes: bytes);
      // A cancelled dialog is the owner's answer, not a failure.
      if (saved == null) {
        return const DataExportResult(DataExportOutcome.cancelled);
      }

      return DataExportResult(
        sources.problems.isEmpty
            ? DataExportOutcome.saved
            : DataExportOutcome.savedWithProblems,
        path: saved.path,
      );
    } on Object catch (error, stack) {
      _log.warning('the data could not be exported', error, stack);

      return const DataExportResult(DataExportOutcome.failed);
    }
  }

  /// `orpheus-data-<yyyy-MM-dd>.json`.
  static String _fileName(DateTime now) =>
      'orpheus-data-${exportDateStamp(now)}.json';
}
