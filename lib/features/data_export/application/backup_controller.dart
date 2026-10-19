import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../data/zip_backup_codec.dart';
import '../domain/backup.dart';
import '../domain/data_export.dart';
import 'data_export_controller.dart';
import 'export_sources.dart';

/// Everything a backup ZIP is made from: plain values every one, so that it
/// can be sent to another isolate.
class BackupSources {
  /// Creates the sources.
  const BackupSources({
    required this.export,
    required this.preferences,
    required this.covers,
  });

  /// What the JSON export is made from; `data.json` is built from it.
  final ExportSources export;

  /// The preferences as `preferences.json` carries them.
  final PreferencesSnapshot preferences;

  /// The custom covers of the playlists by playlist id.
  final Map<String, Uint8List> covers;
}

/// [sources] as the encoded backup ZIP, built and encoded off the UI isolate.
///
/// The same reasoning as [encodeOffTheUiIsolate]: a large library is megabytes
/// of JSON, and covers are pictures. [run] is a parameter so that a test can
/// see the work handed over without starting an isolate.
///
/// A top-level function for the reason that one is: a closure inside a
/// provider would take the `Ref` with it, which cannot be sent.
Future<Uint8List> encodeBackupOffTheUiIsolate(
  BackupSources sources, {
  OffIsolateRunner run = Isolate.run,
}) => run(
  () => encodeBackupZip(
    data: buildDataExport(sources.export),
    preferences: sources.preferences,
    covers: sources.covers,
    createdAt: sources.export.now,
    orpheusVersion: sources.export.orpheusVersion,
  ),
);

/// The preferences as the owner has them now, as a backup carries them.
///
/// The language is written the way the settings store keeps it (`pt_BR`,
/// `en`), which is not a language tag with a hyphen; the volume and the
/// folders are read from the store, which is where playback writes the one
/// and the library the other.
PreferencesSnapshot preferencesNow(Ref ref) {
  final preferences = ref.read(preferencesControllerProvider);
  final settings = ref.read(settingsStoreProvider);
  final locale = preferences.locale;
  final country = locale?.countryCode;

  return PreferencesSnapshot(
    themeMode: preferences.themeMode.name,
    locale: locale == null
        ? null
        : country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country',
    opensPlayerOnPlay: preferences.opensPlayerOnPlay,
    rescansAtStartup: preferences.rescansAtStartup,
    fetchesLyricsOnline: preferences.fetchesLyricsOnline,
    checksForUpdatesOnStartup: preferences.checksForUpdatesOnStartup,
    showsAutoPlaylists: preferences.showsAutoPlaylists,
    volume: settings.volume,
    libraryFolders: settings.libraryFolders,
  );
}

/// Backs Orpheus up to a ZIP the owner chooses where to put.
///
/// State is whether a backup is running, which is what the Preferences
/// disable their entry on. One at a time, like the JSON export: asking for
/// another while one runs answers with the one already under way.
///
/// How it ended is a [DataExportResult], the same outcomes the JSON export
/// has: a backup either was saved with everything in it, saved with something
/// missing, cancelled, refused because the library could not be read, or
/// failed.
///
/// **Only reads.** The only thing written is the file the owner picked.
class BackupController extends Notifier<bool> {
  static final Logger _log = Logger('backup');

  Future<DataExportResult>? _running;

  @override
  bool build() => false;

  /// Gathers the owner's data, the playlists' covers and the preferences,
  /// builds the ZIP and offers it to the save dialog.
  ///
  /// Never throws: how it went is the [DataExportResult].
  Future<DataExportResult> backup() {
    final running = _running;
    if (running != null) return running;

    state = true;
    final started = _backup().whenComplete(() {
      _running = null;
      state = false;
    });

    return _running = started;
  }

  Future<DataExportResult> _backup() async {
    try {
      final export = await gatherExportSources(ref);
      if (export == null) {
        return const DataExportResult(DataExportOutcome.libraryFailed);
      }

      final (:covers, :complete) = await _covers(export);
      final sources = BackupSources(
        export: export,
        preferences: preferencesNow(ref),
        covers: covers,
      );
      final bytes = await ref.read(backupEncoderProvider)(sources);

      final saved = await ref
          .read(fileSaverProvider)
          .save(suggestedName: _fileName(export.now), bytes: bytes);
      // A cancelled dialog is the owner's answer, not a failure.
      if (saved == null) {
        return const DataExportResult(DataExportOutcome.cancelled);
      }

      return DataExportResult(
        export.problems.isEmpty && complete
            ? DataExportOutcome.saved
            : DataExportOutcome.savedWithProblems,
        path: saved.path,
      );
    } on Object catch (error, stack) {
      _log.warning('Orpheus could not be backed up', error, stack);

      return const DataExportResult(DataExportOutcome.failed);
    }
  }

  /// The custom cover of each playlist that has one, and whether every one
  /// could be read.
  ///
  /// A cover that cannot be read is left out and the backup carries on: the
  /// playlists are the backup, and a picture is not worth losing them for. A
  /// playlist whose picture is simply gone has nothing to save and is not a
  /// problem; it shows no cover either.
  Future<({Map<String, Uint8List> covers, bool complete})> _covers(
    ExportSources export,
  ) async {
    final store = ref.read(playlistCoverStoreProvider);
    final covers = <String, Uint8List>{};
    var complete = true;

    for (final playlist in export.playlists) {
      if (playlist.coverId == null) continue;

      try {
        final bytes = await store.read(playlist.id);
        if (bytes != null) covers[playlist.id] = bytes;
      } on Object catch (error) {
        _log.warning(
          'the cover of playlist ${playlist.id} could not be read',
          error,
        );
        complete = false;
      }
    }

    return (covers: covers, complete: complete);
  }

  /// `orpheus-backup-<yyyy-MM-dd>.zip`.
  static String _fileName(DateTime now) =>
      'orpheus-backup-${exportDateStamp(now)}.zip';
}
