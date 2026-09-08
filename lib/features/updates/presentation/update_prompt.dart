import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/update_controller.dart';
import '../domain/update_installer.dart';

/// Watches for an offered update and puts the prompt on screen.
///
/// A listener wrapped around the shell rather than a widget inside it, because
/// what it shows is a dialog and a dialog needs a navigator above whatever
/// asked for it. It draws nothing itself.
class UpdatePromptScope extends ConsumerStatefulWidget {
  /// Wraps [child].
  const UpdatePromptScope({required this.child, super.key});

  /// The application under it.
  final Widget child;

  @override
  ConsumerState<UpdatePromptScope> createState() => _UpdatePromptScopeState();
}

class _UpdatePromptScopeState extends ConsumerState<UpdatePromptScope> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    // Opened when a release is found and never re-opened while it is up: the
    // dialog reads the same provider it was opened from, so every later stage
    // — downloading, failed, handed off — is a rebuild of the dialog already
    // on screen rather than a second one over it.
    ref.listen(updateControllerProvider, (previous, next) {
      if (next.stage == UpdateStage.idle || _showing) return;

      _showing = true;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => const _UpdateDialog(),
        ).whenComplete(() => _showing = false),
      );
    });

    return widget.child;
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);

    final release = state.release;
    if (release == null) return const SizedBox.shrink();

    final current = ref.read(runningVersionProvider);

    return AlertDialog(
      title: Text(
        state.stage == UpdateStage.needsCommand
            ? l10n.updateNeedsCommandTitle
            : l10n.updateAvailableTitle('${release.version}'),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: switch (state.stage) {
              UpdateStage.needsCommand => [
                Text(l10n.updateNeedsCommandBody),
                const SizedBox(height: AppSpacing.md),
                _Command(command: state.command ?? ''),
              ],
              UpdateStage.downloading => [
                Text(
                  state.progress == null
                      ? l10n.updateVerifying
                      : l10n.updateDownloading,
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(value: state.progress),
              ],
              UpdateStage.handedOff => [Text(l10n.updateHandedOff)],
              UpdateStage.failed => [
                Text(
                  switch (state.failure) {
                    UpdateFailure.noPackage => l10n.updateFailedNoPackage,
                    UpdateFailure.checksumMismatch => l10n.updateFailedChecksum,
                    UpdateFailure.launchFailed => l10n.updateFailedLaunch,
                    _ => l10n.updateFailedDownload,
                  },
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              _ => [
                if (current != null) Text(l10n.updateCurrentVersion('$current')),
                if (release.notes case final notes?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.updateReleaseNotes,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // The notes as the release wrote them. Not rendered as
                  // Markdown: this application has no Markdown renderer, and
                  // one added for a paragraph an owner reads twice a year
                  // would be a dependency for a paragraph.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        notes,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ],
            },
          ),
        ),
      ),
      actions: switch (state.stage) {
        UpdateStage.downloading || UpdateStage.handedOff => const [],
        UpdateStage.needsCommand => [
          TextButton(
            onPressed: controller.dismiss,
            child: Text(l10n.updateClose),
          ),
        ],
        UpdateStage.failed => [
          TextButton(
            onPressed: controller.dismiss,
            child: Text(l10n.updateClose),
          ),
          // Absent for a checksum mismatch. What failed there is not the
          // network, and offering to run it again invites the owner to keep
          // trying until something they should not run finally does.
          if (state.failure != UpdateFailure.checksumMismatch)
            FilledButton(
              onPressed: () => unawaited(controller.download()),
              child: Text(l10n.updateRetry),
            ),
        ],
        _ => [
          TextButton(
            onPressed: () => unawaited(controller.skip()),
            child: Text(l10n.updateSkip),
          ),
          TextButton(
            onPressed: controller.dismiss,
            child: Text(l10n.updateLater),
          ),
          FilledButton(
            onPressed: () => unawaited(controller.download()),
            child: Text(l10n.updateNow),
          ),
        ],
      },
    );
  }
}

/// The command to run, in a box that can be copied rather than retyped.
class _Command extends StatefulWidget {
  const _Command({required this.command});

  final String command;

  @override
  State<_Command> createState() => _CommandState();
}

class _CommandState extends State<_Command> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.command));
              if (mounted) setState(() => _copied = true);
            },
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
            label: Text(_copied ? l10n.updateCommandCopied : l10n.updateCopyCommand),
          ),
        ],
      ),
    );
  }
}
