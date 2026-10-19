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
class ExportDataTile extends ConsumerWidget {
  /// Creates the tile.
  const ExportDataTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exporting = ref.watch(dataExportControllerProvider);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !exporting,
      leading: const Icon(Icons.download_outlined),
      title: Text(l10n.dataExportAction),
      trailing: exporting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => unawaited(_export(context, ref)),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Taken before the export, which can outlive the dialog it was started
    // from: the messenger belongs to the application, not to the dialog.
    final messenger = ScaffoldMessenger.of(context);

    final result = await ref
        .read(dataExportControllerProvider.notifier)
        .export();

    final said = switch (result.outcome) {
      // A cancelled dialog is the owner's answer, not something to report.
      DataExportOutcome.cancelled => null,
      // Where it went when that is a path; on Android it is a document
      // provider's address, and only that it was exported is worth saying.
      DataExportOutcome.saved =>
        result.path == null
            ? l10n.dataExported
            : l10n.dataExportSaved(result.path!),
      DataExportOutcome.savedWithProblems => l10n.dataExportPartial,
      DataExportOutcome.libraryFailed => l10n.dataExportLibraryFailed,
      DataExportOutcome.failed => l10n.dataExportFailed,
    };
    if (said != null) messenger.showSnackBar(SnackBar(content: Text(said)));
  }
}
