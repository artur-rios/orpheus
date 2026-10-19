import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

/// *About these exports*: what the JSON export and the backup ZIP each hold,
/// side by side, so that the owner can choose between them.
class AboutExportsDialog extends StatelessWidget {
  /// Creates the dialog.
  const AboutExportsDialog({super.key});

  /// Opens it over [context].
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => const AboutExportsDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleSmall;

    // A mark rather than a word, so that the table reads at a glance; spoken
    // as the word, so that it reads at all to a screen reader.
    Widget mark(bool included) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        included ? '✓' : '—',
        semanticsLabel: included
            ? l10n.backupAboutIncluded
            : l10n.backupAboutNotIncluded,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: included
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget words(String text, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(text, style: style),
    );

    TableRow row(String label, bool json, bool zip) =>
        TableRow(children: [words(label), mark(json), mark(zip)]);

    return AlertDialog(
      title: Text(l10n.backupAboutTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(5),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  words(''),
                  words(l10n.backupAboutColumnJson, style: heading),
                  words(l10n.backupAboutColumnZip, style: heading),
                ],
              ),
              TableRow(
                children: [
                  words(l10n.backupAboutFor, style: heading),
                  words(l10n.backupAboutForJson),
                  words(l10n.backupAboutForZip),
                ],
              ),
              row(l10n.backupAboutSongs, true, true),
              row(l10n.backupAboutPlaylists, true, true),
              row(l10n.backupAboutAutoPlaylists, true, true),
              row(l10n.backupAboutHistory, true, true),
              row(l10n.backupAboutCovers, false, true),
              row(l10n.backupAboutPreferences, false, true),
              row(l10n.backupAboutMusicFiles, false, false),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
