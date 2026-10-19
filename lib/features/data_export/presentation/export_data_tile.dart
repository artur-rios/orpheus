import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../application/data_export_controller.dart';

/// The Preferences entry that exports the owner's data, and what it says about
/// how that went.
///
/// A progress indicator and no way to tap again while an export runs: the
/// library, the playlists and the history are waited for, and a large library
/// takes a moment to build.
///
/// The result is a line under the entry rather than a snackbar. The entry
/// lives in a dialog, and a snackbar would show on the screen behind it,
/// dimmed by the barrier, and be gone in a few seconds, which is not how to
/// tell someone their backup is incomplete. The line stays until the next
/// export starts or the dialog closes.
class ExportDataTile extends ConsumerStatefulWidget {
  /// Creates the tile.
  const ExportDataTile({super.key});

  @override
  ConsumerState<ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends ConsumerState<ExportDataTile> {
  /// What the last export said, and whether it is something to worry about.
  ({String text, bool isProblem})? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exporting = ref.watch(dataExportControllerProvider);
    final status = _status;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !exporting,
      leading: const Icon(Icons.download_outlined),
      title: Text(l10n.dataExportAction),
      subtitle: status == null
          ? null
          // A live region, so that a screen reader announces how the export
          // went when the line appears, without the owner having to go and
          // find it.
          : Semantics(
              liveRegion: true,
              child: Text(
                status.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: status.isProblem
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
      trailing: exporting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => unawaited(_export(l10n)),
    );
  }

  Future<void> _export(AppLocalizations l10n) async {
    // The last result is out of date the moment another export starts.
    setState(() => _status = null);

    final result = await ref
        .read(dataExportControllerProvider.notifier)
        .export();

    // The dialog can be closed while the export runs; its result then has
    // nowhere to be said.
    if (!mounted) return;

    setState(() {
      _status = switch (result.outcome) {
        // A cancelled dialog is the owner's answer, not something to report.
        DataExportOutcome.cancelled => null,
        // Where it went when that is a path; on Android it is a document
        // provider's address, and only that it was exported is worth saying.
        DataExportOutcome.saved => (
          text: result.path == null
              ? l10n.dataExported
              : l10n.dataExportSaved(result.path!),
          isProblem: false,
        ),
        DataExportOutcome.savedWithProblems => (
          text: l10n.dataExportPartial,
          isProblem: true,
        ),
        DataExportOutcome.libraryFailed => (
          text: l10n.dataExportLibraryFailed,
          isProblem: true,
        ),
        DataExportOutcome.failed => (
          text: l10n.dataExportFailed,
          isProblem: true,
        ),
      };
    });
  }
}
