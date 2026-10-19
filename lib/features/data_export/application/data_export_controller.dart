import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_grouping.dart';
import '../../playlists/domain/playlist.dart';
import '../../stats/domain/play_history.dart';
import '../../updates/application/update_controller.dart';
import '../domain/data_export.dart';

/// How an export ended.
enum DataExportOutcome {
  /// The file was saved, with everything in it.
  saved,

  /// The file was saved, but a source could not be read, so the document says
  /// a section is empty for that reason.
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
      // Waited for rather than read as it stands: an export made while a
      // source is still loading would present an empty section as the owner's
      // data.
      final catalog = await _libraryOrNull();
      if (catalog == null) {
        return const DataExportResult(DataExportOutcome.libraryFailed);
      }

      final problems = <ExportProblem>[];
      final playlists = await _playlists(problems);
      final history = await _history(problems);

      final now = ref.read(clockProvider)();
      final sources = ExportSources(
        songs: songsIn(catalog.entries),
        playlists: playlists,
        history: history,
        now: now,
        orpheusVersion: ref.read(runningVersionProvider)?.toString(),
        problems: problems,
      );
      final bytes = await ref.read(dataExportEncoderProvider)(sources);

      final saved = await ref
          .read(fileSaverProvider)
          .save(suggestedName: _fileName(now), bytes: bytes);
      // A cancelled dialog is the owner's answer, not a failure.
      if (saved == null) {
        return const DataExportResult(DataExportOutcome.cancelled);
      }

      return DataExportResult(
        problems.isEmpty
            ? DataExportOutcome.saved
            : DataExportOutcome.savedWithProblems,
        path: saved.path,
      );
    } on Object catch (error, stack) {
      _log.warning('the data could not be exported', error, stack);

      return const DataExportResult(DataExportOutcome.failed);
    }
  }

  /// The library once it has loaded, or `null` when it could not be.
  Future<MusicCatalog?> _libraryOrNull() async {
    try {
      return await ref.read(musicLibraryControllerProvider.future);
    } on Object catch (error) {
      _log.warning('the library could not be read for the export', error);

      return null;
    }
  }

  /// The playlists, or none and a problem saying why when they cannot be read.
  Future<List<Playlist>> _playlists(List<ExportProblem> problems) async {
    try {
      return await ref.read(playlistsControllerProvider.future);
    } on Object catch (error) {
      _log.warning('the playlists could not be read for the export', error);
      problems.add(
        ExportProblem('playlists', 'The playlists could not be read: $error'),
      );

      return const [];
    }
  }

  /// The play history, or none and a problem saying why when it could not be
  /// read.
  ///
  /// The recorder does not fail on an unreadable store: it answers an empty
  /// history and remembers that it could not read it, which is what is asked
  /// after the history has been waited for.
  Future<PlayHistory> _history(List<ExportProblem> problems) async {
    try {
      final history = await ref.read(playHistoryProvider.future);
      if (!ref.read(playRecorderProvider).readFailed) return history;
    } on Object catch (error) {
      _log.warning('the play history could not be read for the export', error);
    }

    problems.add(
      const ExportProblem(
        'playHistory',
        'The play history could not be read, so no plays are listed',
      ),
    );

    return PlayHistory.empty;
  }

  /// `orpheus-data-<yyyy-MM-dd>.json`, on the owner's calendar rather than
  /// UTC's: the date on the file is the day they pressed the button.
  static String _fileName(DateTime now) {
    final local = now.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return 'orpheus-data-$year-$month-$day.json';
  }
}
