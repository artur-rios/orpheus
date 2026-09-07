import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/failures/failure.dart';
import '../../../core/failures/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/library_scan.dart';

/// What the scan is doing, wherever the owner happens to be.
///
/// Above the playback bar and below everything else, and it takes no height at
/// all when there is nothing to say — so the shell is unchanged for anyone who
/// is not scanning, which is almost always.
///
/// It reports and never blocks. A scan runs on an isolate of its own and the
/// library on screen is the previous one until it finishes, so there is
/// nothing here to wait for and no reason to stop the owner listening to
/// something while it works.
///
/// Two things are worth reporting: a scan running, and a scan that could not
/// run. The second is why this exists at all rather than the folders screen
/// carrying the whole story — the scan an owner is most likely to be failed by
/// is the one at startup, which they never asked for and are not standing in
/// front of.
class ScanStrip extends ConsumerWidget {
  /// Creates the strip.
  const ScanStrip({this.showsFailure = true, super.key});

  /// Whether a failed scan is reported here.
  ///
  /// Turned off by the shell while the owner is on the folders screen, which
  /// says the same thing in more detail and offers the way out of a permanent
  /// refusal. One notice, wherever the owner is standing.
  final bool showsFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    if (!scan.isVisible) return const SizedBox.shrink();

    if (scan.failure case final failure? when showsFailure) {
      return _ScanFailed(failure: failure);
    }

    final progress = scan.progress;
    if (!scan.isRunning || progress == null) return const SizedBox.shrink();

    return _ScanRunning(progress: progress);
  }
}

/// How far the running scan has got.
class _ScanRunning extends StatelessWidget {
  const _ScanRunning({required this.progress});

  final ScanProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress.walking
                  ? l10n.scanWalking(progress.filesFound)
                  : l10n.scanReading(progress.filesRead, progress.filesFound),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            // Indeterminate while the walk is still finding files: a bar
            // measured against a total that is still growing is a bar that
            // goes backwards.
            LinearProgressIndicator(value: progress.fraction),
          ],
        ),
      ),
    );
  }
}

/// Why the last scan could not run, with the way to clear it.
///
/// Dismissable, like the notices the playback bar carries above it: the scan
/// is over, and a report with no way to clear it stays for the rest of the
/// session.
class _ScanFailed extends ConsumerWidget {
  const _ScanFailed({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                failure.localizedMessage(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: ref.read(scanControllerProvider.notifier).acknowledge,
              child: Text(l10n.dismiss),
            ),
          ],
        ),
      ),
    );
  }
}
