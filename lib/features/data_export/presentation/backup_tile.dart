import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../application/data_export_controller.dart';
import 'export_action_tile.dart';

/// The Preferences entry that backs Orpheus up to a ZIP, and what it says about
/// how that went.
class BackupTile extends ConsumerWidget {
  /// Creates the tile.
  const BackupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ExportActionTile(
      icon: Icons.archive_outlined,
      title: l10n.backupAction,
      explanation: l10n.backupExplanation,
      running: ref.watch(backupControllerProvider),
      run: () => ref.read(backupControllerProvider.notifier).backup(),
      statusOf: (result) => switch (result.outcome) {
        // A cancelled dialog is the owner's answer, not something to report.
        DataExportOutcome.cancelled => null,
        // Where it went when that is a path; on Android it is a document
        // provider's address, and only that it was backed up is worth saying.
        DataExportOutcome.saved => (
          text: result.path == null
              ? l10n.backedUp
              : l10n.backupSaved(result.path!),
          isProblem: false,
        ),
        DataExportOutcome.savedWithProblems => (
          text: l10n.backupPartial,
          isProblem: true,
        ),
        DataExportOutcome.libraryFailed => (
          text: l10n.backupLibraryFailed,
          isProblem: true,
        ),
        DataExportOutcome.failed => (text: l10n.backupFailed, isProblem: true),
      },
    );
  }
}
