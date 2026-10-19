import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../application/data_export_controller.dart';
import 'export_action_tile.dart';

/// The Preferences entry that exports the owner's data as JSON, and what it
/// says about how that went.
class ExportDataTile extends ConsumerWidget {
  /// Creates the tile.
  const ExportDataTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ExportActionTile(
      icon: Icons.download_outlined,
      title: l10n.dataExportAction,
      explanation: l10n.dataExportExplanation,
      running: ref.watch(dataExportControllerProvider),
      run: () => ref.read(dataExportControllerProvider.notifier).export(),
      statusOf: (result) => switch (result.outcome) {
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
      },
    );
  }
}
