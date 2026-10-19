import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/failures/failure.dart';
import '../../library/domain/music_entry.dart';
import '../data/zip_backup_codec.dart';
import '../domain/backup.dart';
import '../domain/restore_plan.dart';
import 'backup_controller.dart';
import 'data_export_controller.dart';

/// [bytes] read as a backup ZIP or a data JSON, off the UI isolate.
///
/// A backup is megabytes of JSON and a folder of pictures, and unpacking and
/// parsing it on the UI isolate would freeze the screen that is showing the
/// owner it is being read. Throws what [readBackup] throws. [run] is a
/// parameter so that a test can see the work handed over without starting an
/// isolate.
Future<BackupContents> readBackupOffTheUiIsolate(
  Uint8List bytes, {
  OffIsolateRunner run = Isolate.run,
}) => run(() => readBackup(bytes));

/// Where a restore is.
enum RestoreStage {
  /// Nothing is being restored.
  idle,

  /// The picked file is being read.
  reading,

  /// Stage 1, for a backup ZIP: the backup's music folders and this device's,
  /// for the owner to confirm or change.
  folders,

  /// The folders are being applied and the library scanned, or a scan under
  /// way is being waited for, so the backup's songs can be matched against
  /// the library.
  scanning,

  /// Stage 2: what the file holds, and a choice for each part.
  choices,

  /// The parts are being written.
  restoring,

  /// The restore has finished; [RestoreState.summary] says how it went.
  done,

  /// The file could not be read as a backup, or the restore could not be
  /// prepared; [RestoreState.failure] says why. Nothing was restored.
  failed,
}

/// A part of the owner's data a restore writes, each by its own choice.
enum RestorePart {
  /// The playlists, with their covers.
  playlists,

  /// The play history, which the statistics and the auto playlists follow.
  history,

  /// The preferences, apart from the music folders.
  preferences,
}

/// Why a part was not restored.
enum RestoreRefusal {
  /// The backup could not read it when it was made, so what it holds of it is
  /// not the owner's data.
  notInBackup,

  /// The file carries none: a data JSON has no preferences.
  notInFile,

  /// What this device holds of it could not be read, and is not written over.
  unreadableHere,

  /// It could not be written; what was there is as it was.
  notWritten,
}

/// One of the backup's music folders, and whether this device has it.
class FolderStatus {
  /// Creates the status of [path].
  const FolderStatus({required this.path, required this.found});

  /// The folder, as the backup named it.
  final String path;

  /// Whether a folder of that name exists on this device.
  final bool found;
}

/// What a picked file holds, for the owner to see before anything is written.
class BackupOverview {
  /// Creates the overview.
  const BackupOverview({
    required this.createdAt,
    required this.isFullBackup,
    required this.playlists,
    required this.songsWithPlays,
    required this.covers,
    required this.hasPreferences,
  });

  /// The overview of [backup].
  factory BackupOverview.of(BackupContents backup) {
    int count(String section) {
      final value = backup.data[section];

      return value is List ? value.length : 0;
    }

    return BackupOverview(
      createdAt: backup.createdAt,
      isFullBackup: backup.isFullBackup,
      playlists: count(_playlistsSection),
      songsWithPlays: count(_historySection),
      covers: backup.covers.length,
      hasPreferences: backup.preferences != null,
    );
  }

  /// When the file was made, or `null` when it does not say.
  final DateTime? createdAt;

  /// Whether it is a backup ZIP rather than a data JSON.
  final bool isFullBackup;

  /// How many playlists it holds.
  final int playlists;

  /// How many songs it holds plays of.
  final int songsWithPlays;

  /// How many playlist covers it holds.
  final int covers;

  /// Whether it holds the preferences.
  final bool hasPreferences;
}

/// What a restore shows: where it is, what the file holds, and what the owner
/// has chosen.
class RestoreState {
  /// Creates a state.
  const RestoreState({
    this.stage = RestoreStage.idle,
    this.failure,
    this.overview,
    this.backupFolders = const [],
    this.deviceFolders = const [],
    this.stagedFolders,
    this.foldersChanged = false,
    this.scanFailed = false,
    this.choices = defaultChoices,
    this.disabled = const {},
    this.playlistsHere,
    this.songsWithPlaysHere,
    this.summary,
  });

  /// Nothing is being restored.
  static const RestoreState idle = RestoreState();

  /// Every part merged, which never loses anything here.
  static const Map<RestorePart, RestoreChoice> defaultChoices = {
    RestorePart.playlists: RestoreChoice.merge,
    RestorePart.history: RestoreChoice.merge,
    RestorePart.preferences: RestoreChoice.merge,
  };

  /// Where the restore is.
  final RestoreStage stage;

  /// Why the file was not read, at [RestoreStage.failed]; `null` there when
  /// something unforeseen stopped the restore before anything was written.
  final BackupReadFailure? failure;

  /// What the file holds, once it has been read.
  final BackupOverview? overview;

  /// The backup's music folders, each with whether this device has it; empty
  /// for a data JSON, which names none.
  final List<FolderStatus> backupFolders;

  /// This device's music folders as they are now.
  final List<String> deviceFolders;

  /// The folders the owner chose in stage 1, not yet applied; `null` while
  /// they have chosen none.
  final List<String>? stagedFolders;

  /// Whether stage 1 changed this device's music folders. A cancel after it
  /// keeps them, and the library has been scanned with them. Kept at
  /// [RestoreStage.failed] too, when something unforeseen stopped the restore
  /// after it.
  final bool foldersChanged;

  /// Whether the library could not be scanned in stage 1 — the scan failed,
  /// or access to the music was refused — so the backup's songs are matched
  /// against a library that may not hold them.
  final bool scanFailed;

  /// What is done with each part.
  final Map<RestorePart, RestoreChoice> choices;

  /// The parts that cannot be restored from this file, and why.
  final Map<RestorePart, RestoreRefusal> disabled;

  /// How many playlists there are here — what a *Replace* removes — or `null`
  /// when they could not be read.
  final int? playlistsHere;

  /// How many songs have plays here — what a *Replace* replaces the counts
  /// of — or `null` when the history could not be read.
  final int? songsWithPlaysHere;

  /// How the restore went, at [RestoreStage.done].
  final RestoreSummary? summary;

  /// A copy with the given changes.
  RestoreState copyWith({
    RestoreStage? stage,
    List<String>? stagedFolders,
    Map<RestorePart, RestoreChoice>? choices,
    RestoreSummary? summary,
  }) => RestoreState(
    stage: stage ?? this.stage,
    failure: failure,
    overview: overview,
    backupFolders: backupFolders,
    deviceFolders: deviceFolders,
    stagedFolders: stagedFolders ?? this.stagedFolders,
    foldersChanged: foldersChanged,
    scanFailed: scanFailed,
    choices: choices ?? this.choices,
    disabled: disabled,
    playlistsHere: playlistsHere,
    songsWithPlaysHere: songsWithPlaysHere,
    summary: summary ?? this.summary,
  );
}

/// How one part of a restore went.
sealed class PartResult {
  const PartResult();
}

/// The part was not restored, for [reason]; nothing of it was written.
final class PartRefused extends PartResult {
  /// Creates the refusal.
  const PartRefused(this.reason, {this.error});

  /// Why.
  final RestoreRefusal reason;

  /// What went wrong, where something did: for the log, not the owner.
  final Object? error;
}

/// The playlists were restored.
final class PlaylistsRestored extends PartResult {
  /// Creates the result.
  const PlaylistsRestored({
    required this.added,
    required this.merged,
    required this.replaced,
  });

  /// How many playlists the backup added.
  final int added;

  /// How many playlists here it added songs or a cover to.
  final int merged;

  /// How many playlists here it removed, for a *Replace*.
  final int replaced;
}

/// The play history was restored.
final class HistoryRestored extends PartResult {
  /// Creates the result.
  const HistoryRestored({required this.songs, required this.notInLibrary});

  /// How many songs the backup's plays were applied to.
  final int songs;

  /// How many of those the library does not hold, which keep their backup
  /// path until the file turns up.
  final int notInLibrary;
}

/// The preferences were restored.
final class PreferencesRestored extends PartResult {
  /// Creates the result.
  const PreferencesRestored({required this.changed, this.unsaved = false});

  /// Whether any preference changed.
  final bool changed;

  /// Whether one applied but could not be saved, and holds only until the
  /// application closes.
  final bool unsaved;
}

/// How a restore went, part by part.
class RestoreSummary {
  /// Creates the summary.
  const RestoreSummary({
    required this.playlists,
    required this.history,
    required this.preferences,
    this.coverFailures = const [],
  });

  /// How the playlists went.
  final PartResult playlists;

  /// How the play history went.
  final PartResult history;

  /// How the preferences went.
  final PartResult preferences;

  /// The names of the playlists restored whose cover could not be written, or
  /// that the backup holds too large to read: the playlist is there, its
  /// picture is not.
  final List<String> coverFailures;
}

/// The data document's section holding the playlists.
const String _playlistsSection = 'playlists';

/// The data document's section holding the play history.
const String _historySection = 'playHistory';

/// Restores Orpheus from a backup ZIP or a data JSON the owner picks.
///
/// Two stages, as the restore screen shows them. For a ZIP, the backup's music
/// folders first ([RestoreStage.folders]): the songs of a backup can only be
/// matched against the library once the music is where Orpheus looks. Then
/// what to do with each part ([RestoreStage.choices]), each *Merge* by
/// default, which never loses anything here.
///
/// **Nothing is written before the owner says so.** Reading the file, showing
/// the folders and the choices only read; [continueToChoices] is what changes
/// the music folders, and [restore] what writes the data.
///
/// **Each part is whole or untouched.** The playlists are one write of the
/// whole list and the history one write of the whole history; a part whose
/// store here could not be read is refused rather than written over, and one
/// the backup could not read when it was made is never offered. A part that
/// fails does not stop the others, and the [RestoreSummary] says which went
/// how.
///
/// **The music is never touched.** No music file is changed, and the music
/// folders change only through stage 1's explicit choice.
class RestoreController extends Notifier<RestoreState> {
  static final Logger _log = Logger('restore');

  /// Counts the restores started, so that one cancelled — or replaced by a
  /// new pick — does not move the screen on when its work comes back.
  int _session = 0;

  BackupContents? _backup;
  SongMatcher? _matcher;
  Future<RestoreSummary>? _restoring;

  @override
  RestoreState build() => RestoreState.idle;

  /// Asks the owner for a backup ZIP or a data JSON, and reads it off the UI
  /// isolate.
  ///
  /// A ZIP moves to [RestoreStage.folders] and a JSON, which names no
  /// folders, straight to [RestoreStage.choices]; a file that is not a backup,
  /// or is one from a newer Orpheus, to [RestoreStage.failed]. A cancelled
  /// dialog is [RestoreStage.idle]. Nothing is written.
  Future<void> pick() async {
    if (state.stage == RestoreStage.restoring) return;
    final session = ++_session;
    _forget();
    state = RestoreState.idle;

    final Uint8List? bytes;
    try {
      bytes = await ref
          .read(fileOpenerProvider)
          .open(extensions: const ['zip', 'json']);
    } on Object catch (error) {
      _log.warning('the picked file could not be read', error);
      if (session == _session) _fail(const NotABackup());
      return;
    }
    if (session != _session || bytes == null) return;

    state = const RestoreState(stage: RestoreStage.reading);
    final BackupContents backup;
    try {
      backup = await ref.read(backupReaderProvider)(bytes);
    } on BackupReadFailure catch (failure) {
      if (session == _session) _fail(failure);
      return;
    } on Object catch (error) {
      _log.warning('the picked file could not be read as a backup', error);
      if (session == _session) _fail(const NotABackup());
      return;
    }
    if (session != _session) return;

    try {
      _show(backup);
    } on Object catch (error, stack) {
      _failUnexpectedly(session, error, stack);
      return;
    }
    if (!backup.isFullBackup) {
      await _toChoices(session, foldersChanged: false, scanFailed: false);
    }
  }

  /// Shows what [backup] holds: its folders for a ZIP, or, for a data JSON,
  /// the reading on its way to the choices.
  void _show(BackupContents backup) {
    _backup = backup;
    final overview = BackupOverview.of(backup);
    final exists = ref.read(folderExistsProvider);
    final backupFolders = [
      for (final folder
          in backup.preferences?.libraryFolders ?? const <String>[])
        FolderStatus(path: folder, found: exists(folder)),
    ];
    final deviceFolders = ref.read(libraryFoldersControllerProvider);
    // A device with no music folders has no library to match the backup's
    // songs against, so the backup's folders that are here are staged for it:
    // *Continue* without choosing still gives the restore something to match.
    // Staged is not applied; the owner sees the set, and can change it.
    final here = [
      for (final folder in backupFolders)
        if (folder.found) folder.path,
    ];
    state = RestoreState(
      stage: backup.isFullBackup ? RestoreStage.folders : RestoreStage.reading,
      overview: overview,
      backupFolders: backupFolders,
      deviceFolders: deviceFolders,
      stagedFolders: deviceFolders.isEmpty && here.isNotEmpty
          ? List.unmodifiable(here)
          : null,
    );
  }

  /// Stages [folders] as this device's music folders, all of them: a folder
  /// not among them is taken out of the library when the owner continues.
  ///
  /// Nothing is written until [continueToChoices].
  void chooseFolders(List<String> folders) {
    if (state.stage != RestoreStage.folders) return;

    state = state.copyWith(stagedFolders: List.unmodifiable(folders));
  }

  /// Applies the folders chosen in stage 1, scans the library with them, and
  /// moves to the choices once the scan has finished.
  ///
  /// Folders that were not changed are not written; the library is still
  /// scanned first when it is empty or was written by another version, since
  /// the backup's songs are matched against it. The scan runs to its end even
  /// when the owner cancels meanwhile: folders already changed are owed the
  /// library they describe.
  Future<void> continueToChoices() async {
    if (state.stage != RestoreStage.folders) return;
    final session = _session;
    final chosen = state.stagedFolders;
    state = state.copyWith(stage: RestoreStage.scanning);

    final current = ref.read(libraryFoldersControllerProvider);
    final changed = chosen != null && !_sameFolders(chosen, current);
    var scanFailed = false;
    try {
      if (changed) await _setFolders(chosen);
      if (changed || await _libraryWantsScan()) {
        await _scanned();
        scanFailed = _lastScanFailed();
      }
    } on Object catch (error) {
      // The choices still work against whatever library there is: fewer
      // songs matched is a smaller restore, not a wrong one.
      _log.warning('the library could not be scanned for the restore', error);
      scanFailed = true;
    }
    if (session != _session) return;

    await _toChoices(session, foldersChanged: changed, scanFailed: scanFailed);
  }

  /// Chooses what is done with [part]. A part the file cannot restore keeps
  /// its choice, and is not restored whatever it is.
  void choose(RestorePart part, RestoreChoice choice) {
    if (state.stage != RestoreStage.choices) return;
    if (state.disabled.containsKey(part)) return;

    state = state.copyWith(choices: {...state.choices, part: choice});
  }

  /// Writes the parts as chosen — the playlists, then the history, then the
  /// preferences — and answers how each went.
  ///
  /// One at a time: asking again while one runs answers with the one under
  /// way. Never throws once under way, and always ends at
  /// [RestoreStage.done]: a part that could not be restored is a
  /// [PartRefused] in the summary, and should something unforeseen stop the
  /// restore part way, every part not yet written is
  /// [RestoreRefusal.notWritten] and the ones before it say how they went.
  /// Throws a [StateError] when called before the choices are shown.
  Future<RestoreSummary> restore() {
    final running = _restoring;
    if (running != null) return running;
    if (state.stage != RestoreStage.choices) {
      return Future.error(StateError('There is nothing to restore yet.'));
    }

    state = state.copyWith(stage: RestoreStage.restoring);
    final started = _restore()
        .then((summary) {
          state = state.copyWith(stage: RestoreStage.done, summary: summary);
          _forget();

          return summary;
        })
        .whenComplete(() => _restoring = null);

    return _restoring = started;
  }

  /// Leaves the restore, and writes nothing more; the folders stage 1 applied
  /// stay as they are. Also how the summary is closed.
  ///
  /// Ignored while the parts are being written: each is whole or untouched,
  /// and the owner is owed the summary of what was.
  void cancel() {
    if (state.stage == RestoreStage.restoring) return;

    _session++;
    _forget();
    state = RestoreState.idle;
  }

  void _fail(BackupReadFailure failure) =>
      state = RestoreState(stage: RestoreStage.failed, failure: failure);

  /// Something unforeseen stopped the restore before anything of the data was
  /// written: [RestoreStage.failed], which the screen can be closed from,
  /// rather than a screen left busy with no way out.
  ///
  /// [foldersChanged] is kept in the failed state: stage 1 may already have
  /// changed the music folders, which stay, and the screen says so.
  void _failUnexpectedly(
    int session,
    Object error,
    StackTrace stack, {
    bool foldersChanged = false,
  }) {
    _log.severe('the restore could not be prepared', error, stack);
    if (session != _session) return;

    _forget();
    state = RestoreState(
      stage: RestoreStage.failed,
      foldersChanged: foldersChanged,
    );
  }

  void _forget() {
    _backup = null;
    _matcher = null;
  }

  /// Builds the matcher over the library as it is once no scan is running,
  /// and shows the choices.
  ///
  /// Never throws: anything unforeseen is [RestoreStage.failed].
  Future<void> _toChoices(
    int session, {
    required bool foldersChanged,
    required bool scanFailed,
  }) async {
    try {
      await _showChoices(
        session,
        foldersChanged: foldersChanged,
        scanFailed: scanFailed,
      );
    } on Object catch (error, stack) {
      _failUnexpectedly(session, error, stack, foldersChanged: foldersChanged);
    }
  }

  Future<void> _showChoices(
    int session, {
    required bool foldersChanged,
    required bool scanFailed,
  }) async {
    // A scan under way — one the owner started, or the one at startup — is
    // about to change the library the backup's songs are matched against.
    // A data JSON waits for it with the scan's progress on screen.
    if (ref.read(scanControllerProvider).isRunning &&
        state.stage == RestoreStage.reading) {
      state = state.copyWith(stage: RestoreStage.scanning);
    }
    await _noScanRunning();
    final backup = _backup;
    if (backup == null || session != _session) return;

    final deviceFolders = ref.read(libraryFoldersControllerProvider);
    final backupFolders = backup.preferences?.libraryFolders ?? const [];
    // A path moves from the one old folder to the one new folder only when
    // there is exactly one of each; with more, which went where is a guess.
    final moved = backupFolders.length == 1 && deviceFolders.length == 1;
    final matcher = SongMatcher(
      await _library(),
      oldFolder: moved ? backupFolders.single : null,
      newFolder: moved ? deviceFolders.single : null,
    );
    final playlistsHere = await _playlistsHere();
    final songsWithPlaysHere = await _songsWithPlaysHere();
    if (session != _session) return;

    _matcher = matcher;
    final unreadable = unreadableParts(backup);
    state = RestoreState(
      stage: RestoreStage.choices,
      overview: state.overview,
      backupFolders: state.backupFolders,
      deviceFolders: deviceFolders,
      foldersChanged: foldersChanged,
      scanFailed: scanFailed,
      disabled: {
        if (unreadable.contains(_playlistsSection))
          RestorePart.playlists: RestoreRefusal.notInBackup,
        if (unreadable.contains(_historySection))
          RestorePart.history: RestoreRefusal.notInBackup,
        if (backup.preferences == null)
          RestorePart.preferences: RestoreRefusal.notInFile,
      },
      playlistsHere: playlistsHere,
      songsWithPlaysHere: songsWithPlaysHere,
    );
  }

  /// Makes [chosen] the whole of this device's music folders: the ones not
  /// chosen are removed, then the chosen are added, each only where it is
  /// not there already.
  Future<void> _setFolders(List<String> chosen) async {
    final folders = ref.read(libraryFoldersControllerProvider.notifier);
    for (final folder in [...ref.read(libraryFoldersControllerProvider)]) {
      if (!chosen.contains(folder)) await folders.remove(folder);
    }
    await folders.addAll(chosen);
  }

  /// Whether the library has to be scanned before songs can be matched
  /// against it: it has folders, and holds nothing or is stale — another
  /// version's, or one that could not be read.
  Future<bool> _libraryWantsScan() async {
    if (ref.read(libraryFoldersControllerProvider).isEmpty) return false;

    try {
      final catalog = await ref.read(musicLibraryControllerProvider.future);

      return catalog.isStale || catalog.entries.isEmpty;
    } on Object {
      return false;
    }
  }

  /// Scans the music folders and returns once no scan is running.
  ///
  /// A scan already under way may have read the folders before they changed,
  /// so it is waited out and a new one started; asking for one while another
  /// runs answers at once, which is why the end is waited for too.
  Future<void> _scanned() async {
    await _noScanRunning();
    await ref.read(scanControllerProvider.notifier).scan();
    await _noScanRunning();
  }

  /// Whether the scan that just ran did not read the library: it failed, or
  /// access to the music was refused. A catalog read but not saved is a
  /// library all the same.
  bool _lastScanFailed() {
    final failure = ref.read(scanControllerProvider).failure;

    return failure != null && failure is! CatalogUnavailable;
  }

  Future<void> _noScanRunning() async {
    if (!ref.read(scanControllerProvider).isRunning) return;

    final finished = Completer<void>();
    final subscription = ref.listen(scanControllerProvider, (_, next) {
      if (!next.isRunning && !finished.isCompleted) finished.complete();
    });
    try {
      if (ref.read(scanControllerProvider).isRunning) await finished.future;
    } finally {
      subscription.close();
    }
  }

  /// The library's songs, or none when it could not be read: then nothing is
  /// matched, and the backup's songs keep their paths.
  Future<List<MusicEntry>> _library() async {
    try {
      return (await ref.read(musicLibraryControllerProvider.future)).entries;
    } on Object catch (error) {
      _log.warning('the library could not be read for the restore', error);

      return const [];
    }
  }

  Future<int?> _playlistsHere() async {
    try {
      return (await ref.read(playlistsControllerProvider.future)).length;
    } on Object {
      return null;
    }
  }

  Future<int?> _songsWithPlaysHere() async {
    final recorder = ref.read(playRecorderProvider);
    final history = await recorder.current();

    return recorder.readFailed ? null : history.tracks.length;
  }

  /// The parts, in order. Never throws: each part answers how it went, and
  /// should anything unforeseen stop the run, the parts that answered keep
  /// their answer and every other one was not written.
  Future<RestoreSummary> _restore() async {
    PartResult? playlists;
    var coverFailures = const <String>[];
    PartResult? history;
    PartResult? preferences;
    try {
      final backup = _backup!;
      final matcher = _matcher!;
      final choices = state.choices;
      final disabled = state.disabled;
      final now = ref.read(clockProvider)();

      (playlists, coverFailures) = await _restorePlaylists(
        backup,
        matcher,
        choices[RestorePart.playlists]!,
        disabled[RestorePart.playlists],
        now,
      );
      history = await _restoreHistory(
        backup,
        matcher,
        choices[RestorePart.history]!,
        disabled[RestorePart.history],
        now,
      );
      preferences = await _restorePreferences(
        backup,
        choices[RestorePart.preferences]!,
        disabled[RestorePart.preferences],
      );

      return RestoreSummary(
        playlists: playlists,
        history: history,
        preferences: preferences,
        coverFailures: coverFailures,
      );
    } on Object catch (error, stack) {
      _log.severe('the restore stopped part way', error, stack);
      final unwritten = PartRefused(RestoreRefusal.notWritten, error: error);

      return RestoreSummary(
        playlists: playlists ?? unwritten,
        history: history ?? unwritten,
        preferences: preferences ?? unwritten,
        coverFailures: coverFailures,
      );
    }
  }

  /// The playlists: their covers, then the list as one write.
  Future<(PartResult, List<String>)> _restorePlaylists(
    BackupContents backup,
    SongMatcher matcher,
    RestoreChoice choice,
    RestoreRefusal? disabled,
    DateTime now,
  ) async {
    if (disabled != null) return (PartRefused(disabled), const <String>[]);

    try {
      await ref.read(playlistsControllerProvider.future);
    } on Object catch (error) {
      _log.warning('the playlists here could not be read', error);

      return (
        PartRefused(RestoreRefusal.unreadableHere, error: error),
        const <String>[],
      );
    }

    // Worked out in the write's own turn, from the playlists as they are
    // then: a change the owner made just before is built on, not written
    // over.
    final playlists = ref.read(playlistsControllerProvider.notifier);
    PlaylistsOutcome? planned;
    final Set<String> failed;
    try {
      failed = await playlists.replaceAll((before) {
        final outcome = planned = restorePlaylists(
          before,
          backup,
          matcher,
          choice,
          newId: ref.read(idGeneratorProvider),
          now: now,
        );

        // Nothing added, changed or removed is nothing to write.
        return outcome.added + outcome.merged + outcome.replaced == 0
            ? (playlists: before, covers: const <String, Uint8List>{})
            : (playlists: outcome.playlists, covers: outcome.coversToWrite);
      });
    } on Object catch (error) {
      _log.warning('the restored playlists could not be written', error);

      return (
        PartRefused(RestoreRefusal.notWritten, error: error),
        const <String>[],
      );
    }

    final outcome = planned!;

    return (
      PlaylistsRestored(
        added: outcome.added,
        merged: outcome.merged,
        replaced: outcome.replaced,
      ),
      [
        for (final playlist in outcome.playlists)
          if (failed.contains(playlist.id) ||
              outcome.coversLost.contains(playlist.id))
            playlist.name,
      ],
    );
  }

  /// The play history, written whole.
  Future<PartResult> _restoreHistory(
    BackupContents backup,
    SongMatcher matcher,
    RestoreChoice choice,
    RestoreRefusal? disabled,
    DateTime now,
  ) async {
    if (disabled != null) return PartRefused(disabled);

    final recorder = ref.read(playRecorderProvider);
    await recorder.current();
    if (recorder.readFailed) {
      return const PartRefused(RestoreRefusal.unreadableHere);
    }

    // Worked out in the write's own turn, from the history as it is then: a
    // play still waiting to be written is built on, not written over.
    HistoryOutcome? planned;
    try {
      await recorder.replaceHistory((current) {
        final outcome = planned = restoreHistory(
          current,
          backup,
          matcher,
          choice,
          now,
        );

        // A *Replace* with nothing in the backup still empties the history
        // here: that is what the owner chose, having been shown what it
        // replaces. Otherwise no song applied is nothing to write.
        return choice != RestoreChoice.replace && outcome.songs == 0
            ? current
            : outcome.history;
      });
    } on Object catch (error) {
      _log.warning('the restored play history could not be written', error);

      return PartRefused(RestoreRefusal.notWritten, error: error);
    }

    final outcome = planned!;

    return HistoryRestored(
      songs: outcome.songs,
      notInLibrary: outcome.notInLibrary,
    );
  }

  /// The preferences, applied through the same setters the Preferences use.
  Future<PartResult> _restorePreferences(
    BackupContents backup,
    RestoreChoice choice,
    RestoreRefusal? disabled,
  ) async {
    if (disabled != null) return PartRefused(disabled);

    final current = preferencesNow(ref);
    final next = restorePreferences(
      current,
      freshInstallPreferences,
      backup.preferences,
      choice,
    );
    if (next == null || next == current) {
      return const PreferencesRestored(changed: false);
    }

    try {
      final unsaved = await _apply(current, next);

      return PreferencesRestored(changed: true, unsaved: unsaved);
    } on Object catch (error) {
      _log.warning('the restored preferences could not be applied', error);

      return PartRefused(RestoreRefusal.notWritten, error: error);
    }
  }

  /// Applies each value of [next] that differs from [current], and answers
  /// whether any of them could not be saved.
  Future<bool> _apply(
    PreferencesSnapshot current,
    PreferencesSnapshot next,
  ) async {
    final preferences = ref.read(preferencesControllerProvider.notifier);
    var unsaved = false;

    Future<void> apply<T>(
      T Function(PreferencesSnapshot) value,
      Future<void> Function(T value) set,
    ) async {
      if (value(next) == value(current)) return;

      await set(value(next));
      // Each setter clears the flag before it writes, so it is read after
      // each one rather than once at the end.
      if (ref.read(preferencesControllerProvider).unsaved) unsaved = true;
    }

    await apply(
      (p) => p.themeMode,
      (name) => preferences.setThemeMode(_themeMode(name)),
    );
    await apply((p) => p.locale, (tag) => preferences.setLocale(_locale(tag)));
    await apply((p) => p.opensPlayerOnPlay, preferences.setOpensPlayerOnPlay);
    await apply((p) => p.rescansAtStartup, preferences.setRescansAtStartup);
    await apply(
      (p) => p.fetchesLyricsOnline,
      preferences.setFetchesLyricsOnline,
    );
    await apply(
      (p) => p.checksForUpdatesOnStartup,
      preferences.setChecksForUpdatesOnStartup,
    );
    await apply((p) => p.showsAutoPlaylists, preferences.setShowsAutoPlaylists);
    await apply((p) => p.volume, preferences.setVolume);

    return unsaved;
  }

  /// The `ThemeMode` called [name]; one this release does not know follows
  /// the system, as the settings store reads one.
  static ThemeMode _themeMode(String name) =>
      ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;

  /// The language [tag] names, as the settings store keeps it (`pt_BR`), or
  /// `null` to follow the system.
  static Locale? _locale(String? tag) {
    if (tag == null || tag.isEmpty) return null;

    final parts = tag.split('_');

    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  /// Whether [a] and [b] are the same folders, in whatever order.
  static bool _sameFolders(List<String> a, List<String> b) {
    final left = a.toSet();
    final right = b.toSet();

    return left.length == right.length && left.containsAll(right);
  }
}
