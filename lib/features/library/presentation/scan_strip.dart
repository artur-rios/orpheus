import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

/// What the scan is doing, wherever the owner happens to be.
///
/// Above the playback bar and below everything else, and it takes no height at
/// all when nothing is running — so the shell is unchanged for anyone who is
/// not scanning, which is almost always.
///
/// It reports and never blocks. A scan runs on an isolate of its own and the
/// library on screen is the previous one until it finishes, so there is
/// nothing here to wait for and no reason to stop the owner listening to
/// something while it works.
class ScanStrip extends ConsumerWidget {
  /// Creates the strip.
  const ScanStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scan = ref.watch(scanControllerProvider);

    final progress = scan.progress;
    if (!scan.isRunning || progress == null) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.walking
                        ? l10n.scanWalking(progress.filesFound)
                        : l10n.scanReading(
                            progress.filesRead,
                            progress.filesFound,
                          ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Indeterminate while the walk is still finding files: a bar
                  // measured against a total that is still growing is a bar
                  // that goes backwards.
                  LinearProgressIndicator(value: progress.fraction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
