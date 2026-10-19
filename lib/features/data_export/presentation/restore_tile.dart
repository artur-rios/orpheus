import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../application/restore_controller.dart';
import 'restore_screen.dart';

/// The Preferences entry that restores Orpheus from a backup.
///
/// Tapping it asks for the file; once the file is read, the restore screen
/// opens over the Preferences. A dismissed file dialog opens nothing.
class RestoreTile extends ConsumerStatefulWidget {
  /// Creates the tile.
  const RestoreTile({super.key});

  @override
  ConsumerState<RestoreTile> createState() => _RestoreTileState();
}

class _RestoreTileState extends ConsumerState<RestoreTile> {
  /// Whether the file is being asked for or read, so that a second tap does
  /// not open a second file dialog.
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      await ref.read(restoreControllerProvider.notifier).pick();
    } finally {
      if (mounted) setState(() => _opening = false);
    }

    if (!mounted) return;
    // Idle is a dismissed file dialog: the owner's answer, not something to
    // open a screen about.
    if (ref.read(restoreControllerProvider).stage == RestoreStage.idle) return;

    await RestoreScreen.show(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_opening,
      isThreeLine: true,
      leading: const Icon(Icons.unarchive_outlined),
      title: Text(l10n.restoreAction),
      subtitle: Text(l10n.restoreExplanation),
      trailing: _opening
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => unawaited(_open()),
    );
  }
}
