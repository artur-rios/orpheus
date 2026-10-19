import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import 'about_exports_dialog.dart';
import 'backup_tile.dart';
import 'export_data_tile.dart';

/// The *Your data* section of the Preferences: the two ways out of Orpheus,
/// each saying in a line what it is for, and the link that compares them.
///
/// *Restore from a backup…* goes between the backup and the link: the way back
/// in belongs beside the ways out.
class YourDataSection extends StatelessWidget {
  /// Creates the section.
  const YourDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            l10n.dataExportHeading,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const ExportDataTile(),
        const BackupTile(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => AboutExportsDialog.show(context),
            child: Text(l10n.backupAboutAction),
          ),
        ),
      ],
    );
  }
}
