import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/domain/library_scan.dart';
import '../application/restore_controller.dart';
import '../domain/backup.dart';
import '../domain/restore_plan.dart';

/// The restore: a full-screen dialog on a phone, a dialog on a wide window.
///
/// Two stages, as the controller has them. *Your music* first, for a backup
/// ZIP: the backup's folders and this device's, so the songs in the backup can
/// be matched against a library that is where the music is. Then *What to
/// restore*: what the file holds and a choice for each part, each *Merge* by
/// default. Progress while the library is scanned and while the parts are
/// written, and a summary at the end.
///
/// **Nothing is written before the owner presses *Continue* or *Restore*.**
/// While the folders are being applied and scanned, and while the parts are
/// written, the screen cannot be left: each is whole or untouched, and the
/// owner is owed the summary of what was written.
class RestoreScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RestoreScreen({super.key});

  /// Opens it over [context], for the file the controller has read, and ends
  /// the restore when it closes — however it was closed. The music folders
  /// that stage 1 applied stay.
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final restore = ref.read(restoreControllerProvider.notifier);
    await showDialog<void>(
      context: context,
      // Tapping beside the dialog would lose the choices made in it.
      barrierDismissible: false,
      builder: (context) => const RestoreScreen(),
    );
    restore.cancel();
  }

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  /// The last state that was not idle, which is what is shown while the dialog
  /// closes: leaving the restore resets the state, and a dialog that emptied
  /// itself on the way out would flash.
  RestoreState _shown = RestoreState.idle;

  Future<void> _addFolder(List<String> current) async {
    final picked = await ref.read(folderPickerProvider).pickFolder();
    if (picked == null || !mounted) return;

    if (!current.contains(picked)) {
      ref.read(restoreControllerProvider.notifier).chooseFolders([
        ...current,
        picked,
      ]);
    }
  }

  void _removeFolder(List<String> current, String folder) =>
      ref.read(restoreControllerProvider.notifier).chooseFolders([
        for (final other in current)
          if (other != folder) other,
      ]);

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watched = ref.watch(restoreControllerProvider);
    if (watched.stage != RestoreStage.idle) _shown = watched;
    final state = _shown;

    final busy = switch (state.stage) {
      RestoreStage.reading ||
      RestoreStage.scanning ||
      RestoreStage.restoring => true,
      _ => false,
    };
    final controller = ref.read(restoreControllerProvider.notifier);

    final (
      String title,
      Widget body,
      List<Widget> actions,
    ) = switch (state.stage) {
      RestoreStage.failed => (
        l10n.restoreTitle,
        Text(switch (state.failure) {
          NewerBackupVersion() => l10n.restoreFailedNewer,
          NotABackup() => l10n.restoreFailedNotABackup,
          null => l10n.restoreFailedUnexpected,
        }),
        [FilledButton(onPressed: _close, child: Text(l10n.close))],
      ),
      RestoreStage.folders => (
        l10n.restoreFoldersTitle,
        _foldersBody(l10n, state),
        [
          TextButton(onPressed: _close, child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => unawaited(controller.continueToChoices()),
            child: Text(l10n.restoreContinue),
          ),
        ],
      ),
      RestoreStage.scanning => (
        l10n.restoreFoldersTitle,
        _Progress(label: l10n.restoreScanning, scanning: true),
        const <Widget>[],
      ),
      RestoreStage.choices => (
        l10n.restoreChoicesTitle,
        _choicesBody(l10n, state),
        [
          TextButton(onPressed: _close, child: Text(l10n.cancel)),
          FilledButton(
            onPressed: state.disabled.length == RestorePart.values.length
                ? null
                : () => unawaited(controller.restore()),
            child: Text(l10n.restoreRestore),
          ),
        ],
      ),
      RestoreStage.restoring => (
        l10n.restoreChoicesTitle,
        _Progress(label: l10n.restoreRestoring),
        const <Widget>[],
      ),
      RestoreStage.done => (
        l10n.restoreDoneTitle,
        state.summary == null
            ? const SizedBox.shrink()
            : _SummaryView(summary: state.summary!, choices: state.choices),
        [FilledButton(onPressed: _close, child: Text(l10n.close))],
      ),
      RestoreStage.idle || RestoreStage.reading => (
        l10n.restoreTitle,
        const _Progress(label: ''),
        const <Widget>[],
      ),
    };

    final Widget dialog;
    if (Breakpoint.from(context) == Breakpoint.phone) {
      dialog = Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: busy ? null : CloseButton(onPressed: _close),
            title: Text(title),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [body],
          ),
          bottomNavigationBar: actions.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: AppSpacing.sm,
                      children: actions,
                    ),
                  ),
                ),
        ),
      );
    } else {
      dialog = AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: body),
        ),
        actions: actions,
      );
    }

    // Not while the library is scanned or the parts are written: leaving then
    // would hide what was done to the owner's folders and data.
    return PopScope(canPop: !busy, child: dialog);
  }

  Widget _foldersBody(AppLocalizations l10n, RestoreState state) {
    final theme = Theme.of(context);
    final folders = state.stagedFolders ?? state.deviceFolders;
    final changes =
        state.stagedFolders != null &&
        !_sameFolders(state.stagedFolders!, state.deviceFolders);
    const gap = SizedBox(height: AppSpacing.sm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.restoreFoldersIntro),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.restoreBackupFolders, style: theme.textTheme.titleSmall),
        gap,
        if (state.backupFolders.isEmpty)
          Text(l10n.restoreBackupFoldersNone)
        else
          for (final folder in state.backupFolders)
            _FolderRow(
              path: folder.path,
              status: folder.found
                  ? l10n.restoreFolderFound
                  : l10n.restoreFolderNotFound,
              icon: folder.found
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: folder.found
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.restoreDeviceFolders, style: theme.textTheme.titleSmall),
        gap,
        Column(
          key: const ValueKey('restore-device-folders'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (folders.isEmpty && state.deviceFolders.isNotEmpty)
              // Taking every folder out leaves nothing to match songs against.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.restoreFoldersAllRemoved,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              )
            else if (folders.isEmpty)
              Text(l10n.restoreDeviceFoldersNone)
            else
              for (final folder in folders)
                _FolderRow(
                  path: folder,
                  icon: Icons.folder_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  onRemove: () => _removeFolder(folders, folder),
                  removeTooltip: l10n.restoreRemoveFolder(folder),
                ),
          ],
        ),
        if (changes) ...[
          gap,
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.restoreFoldersStaged,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        gap,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(l10n.restoreChooseFolders),
            onPressed: () => unawaited(_addFolder(folders)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.restoreFoldersNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _choicesBody(AppLocalizations l10n, RestoreState state) {
    final theme = Theme.of(context);
    final overview = state.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overview != null) _overview(l10n, overview),
        if (state.scanFailed) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.restoreScanFailed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        for (final part in RestorePart.values) ...[
          const SizedBox(height: AppSpacing.md),
          _PartSection(part: part, state: state),
        ],
        if (state.foldersChanged) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.restoreFoldersKept,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// What the file holds: when it was made, how many playlists and songs with
  /// plays, and whether the covers and the preferences are in it.
  Widget _overview(AppLocalizations l10n, BackupOverview overview) {
    final theme = Theme.of(context);
    final made = overview.createdAt;
    final when = made == null
        ? null
        : DateFormat.yMMMd(Localizations.localeOf(context).toString())
              .format(made.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          when == null
              ? l10n.restoreBackupUndated
              : l10n.restoreBackupFrom(when),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.restoreHoldsPlaylists(overview.playlists)),
        Text(l10n.restoreHoldsSongs(overview.songsWithPlays)),
        Text(l10n.restoreHoldsCovers(overview.covers)),
        Text(
          overview.hasPreferences
              ? l10n.restoreHoldsPreferences
              : l10n.restoreHoldsNoPreferences,
        ),
      ],
    );
  }

  /// Whether [a] and [b] are the same folders, in whatever order.
  static bool _sameFolders(List<String> a, List<String> b) {
    final left = a.toSet();
    final right = b.toSet();

    return left.length == right.length && left.containsAll(right);
  }
}

/// A folder, with a line saying what it is and, where it can go, a button to
/// take it out of the set.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.path,
    required this.icon,
    required this.color,
    this.status,
    this.onRemove,
    this.removeTooltip,
  });

  final String path;
  final String? status;
  final IconData icon;
  final Color color;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A path has no break points, and a deep one would otherwise
                // push the dialog wider than a phone.
                Text(path, softWrap: true),
                if (status != null)
                  Text(
                    status!,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 20),
              tooltip: removeTooltip,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// One part of the restore: its name, the three choices, a line on what the
/// chosen one does, and its warning where *Replace* removes something.
class _PartSection extends ConsumerWidget {
  _PartSection({required this.part, required this.state})
    : super(key: ValueKey('restore-part-${part.name}'));

  final RestorePart part;
  final RestoreState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final refusal = state.disabled[part];
    final choice = state.choices[part] ?? RestoreChoice.merge;
    final controller = ref.read(restoreControllerProvider.notifier);

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final warning = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );

    // What this device holds of the part, for the warning under *Replace*, or
    // `null` when it could not be read: then nothing of the part is written.
    final here = switch (part) {
      RestorePart.playlists => state.playlistsHere,
      RestorePart.history => state.songsWithPlaysHere,
      RestorePart.preferences => 0,
    };
    final unreadableHere = part != RestorePart.preferences && here == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_partName(l10n, part), style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<RestoreChoice>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: RestoreChoice.merge,
                label: Text(l10n.restoreMerge),
              ),
              ButtonSegment(
                value: RestoreChoice.skip,
                label: Text(l10n.restoreSkip),
              ),
              ButtonSegment(
                value: RestoreChoice.replace,
                label: Text(l10n.restoreReplace),
              ),
            ],
            selected: {choice},
            onSelectionChanged: refusal == null
                ? (chosen) => controller.choose(part, chosen.single)
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (refusal != null)
          Text(switch (refusal) {
            RestoreRefusal.notInFile => l10n.restoreNotInFile,
            _ => l10n.restoreNotInBackup,
          }, style: muted)
        else ...[
          Text(_describe(l10n, part, choice), style: muted),
          if (unreadableHere)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                part == RestorePart.playlists
                    ? l10n.restoreUnreadablePlaylists
                    : l10n.restoreUnreadableHistory,
                style: warning,
              ),
            )
          else if (choice == RestoreChoice.replace)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _replaces(l10n, part, here ?? 0),
                      style: warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static String _describe(
    AppLocalizations l10n,
    RestorePart part,
    RestoreChoice choice,
  ) => switch ((part, choice)) {
    (RestorePart.playlists, RestoreChoice.merge) => l10n.restorePlaylistsMerge,
    (RestorePart.playlists, RestoreChoice.skip) => l10n.restorePlaylistsSkip,
    (RestorePart.playlists, RestoreChoice.replace) =>
      l10n.restorePlaylistsReplace,
    (RestorePart.history, RestoreChoice.merge) => l10n.restoreHistoryMerge,
    (RestorePart.history, RestoreChoice.skip) => l10n.restoreHistorySkip,
    (RestorePart.history, RestoreChoice.replace) => l10n.restoreHistoryReplace,
    (RestorePart.preferences, RestoreChoice.merge) =>
      l10n.restorePreferencesMerge,
    (RestorePart.preferences, RestoreChoice.skip) =>
      l10n.restorePreferencesSkip,
    (RestorePart.preferences, RestoreChoice.replace) =>
      l10n.restorePreferencesReplace,
  };

  static String _replaces(AppLocalizations l10n, RestorePart part, int here) =>
      switch (part) {
        RestorePart.playlists => l10n.restoreReplacePlaylists(here),
        RestorePart.history => l10n.restoreReplaceHistory(here),
        RestorePart.preferences => l10n.restoreReplacePreferences,
      };
}

/// What the part is called, in the choices and in the summary.
String _partName(AppLocalizations l10n, RestorePart part) => switch (part) {
  RestorePart.playlists => l10n.restorePartPlaylists,
  RestorePart.history => l10n.restorePartHistory,
  RestorePart.preferences => l10n.restorePartPreferences,
};

/// Something is under way: an indicator, what it is, and for a scan how far it
/// has got.
class _Progress extends ConsumerWidget {
  const _Progress({required this.label, this.scanning = false});

  final String label;

  /// Whether to say how far the library scan has got.
  final bool scanning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = scanning
        ? ref.watch(scanControllerProvider.select((scan) => scan.progress))
        : null;

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress?.fraction),
          const SizedBox(height: AppSpacing.sm),
          Text(label),
          if (progress != null) Text(_progressLine(l10n, progress)),
        ],
      ),
    );
  }

  static String _progressLine(AppLocalizations l10n, ScanProgress progress) =>
      progress.walking
      ? l10n.scanWalking(progress.filesFound)
      : l10n.scanReading(progress.filesRead, progress.filesFound);
}

/// How a restore went: what was restored, then what could not be, and why.
class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary, required this.choices});

  final RestoreSummary summary;

  /// What the owner chose for each part, which tells a *Skip* that added
  /// nothing from a *Replace* that emptied what was here.
  final Map<RestorePart, RestoreChoice> choices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // A line is a success unless it says something went only partly right.
    final restored = <({String text, bool warning})>[];
    final refused = <String>[];

    void say(RestorePart part, PartResult result) {
      switch (result) {
        case PartRefused(:final reason):
          refused.add(
            l10n.restoreRefusedLine(_partName(l10n, part), switch (reason) {
              RestoreRefusal.notInBackup => l10n.restoreReasonNotInBackup,
              RestoreRefusal.notInFile => l10n.restoreReasonNotInFile,
              RestoreRefusal.unreadableHere => l10n.restoreReasonUnreadableHere,
              RestoreRefusal.notWritten => l10n.restoreReasonNotWritten,
            }),
          );
        case PlaylistsRestored(:final added, :final merged, :final replaced):
          final choice = choices[RestorePart.playlists];
          restored.add((
            text: replaced > 0 && added == 0
                ? l10n.restoreDonePlaylistsEmptied(replaced)
                : replaced > 0
                ? l10n.restoreDonePlaylistsReplaced(replaced, added)
                : added + merged > 0
                ? l10n.restoreDonePlaylists(added, merged)
                : choice == RestoreChoice.skip
                ? l10n.restoreDoneSkipped(_partName(l10n, part))
                : l10n.restoreDonePlaylistsNothing,
            warning: false,
          ));
        case HistoryRestored(:final songs, :final notInLibrary):
          final choice = choices[RestorePart.history];
          restored.add((
            text: songs > 0 && notInLibrary > 0
                ? l10n.restoreDoneHistoryMissing(songs, notInLibrary)
                : songs > 0
                ? l10n.restoreDoneHistory(songs)
                : choice == RestoreChoice.replace
                // The history here was emptied, which is what was chosen.
                ? l10n.restoreDoneHistoryEmptied
                : choice == RestoreChoice.skip
                ? l10n.restoreDoneSkipped(_partName(l10n, part))
                : l10n.restoreDoneHistoryNothing,
            warning: false,
          ));
        case PreferencesRestored(:final changed, :final unsaved):
          restored.add((
            text: changed
                ? l10n.restoreDonePreferences
                : choices[RestorePart.preferences] == RestoreChoice.skip
                ? l10n.restoreDoneSkipped(_partName(l10n, part))
                : l10n.restoreDonePreferencesNone,
            warning: false,
          ));
          if (unsaved) {
            restored.add((
              text: l10n.restoreDonePreferencesUnsaved,
              warning: true,
            ));
          }
      }
    }

    say(RestorePart.playlists, summary.playlists);
    if (summary.coverFailures.isNotEmpty) {
      restored.add((
        text: l10n.restoreDoneCoverFailures(summary.coverFailures.join(', ')),
        warning: true,
      ));
    }
    say(RestorePart.history, summary.history);
    say(RestorePart.preferences, summary.preferences);

    Widget line(String text, IconData icon, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (restored.isNotEmpty) ...[
            Text(l10n.restoreDoneRestored, style: theme.textTheme.titleSmall),
            for (final (:text, :warning) in restored)
              // A picture or a setting that did not stick is not the check
              // mark the rest of the lines earned.
              warning
                  ? line(
                      text,
                      Icons.warning_amber_outlined,
                      theme.colorScheme.error,
                    )
                  : line(
                      text,
                      Icons.check_circle_outline,
                      theme.colorScheme.primary,
                    ),
          ],
          if (refused.isNotEmpty) ...[
            if (restored.isNotEmpty) const SizedBox(height: AppSpacing.md),
            Text(l10n.restoreDoneRefused, style: theme.textTheme.titleSmall),
            for (final text in refused)
              line(text, Icons.error_outline, theme.colorScheme.error),
          ],
        ],
      ),
    );
  }
}
