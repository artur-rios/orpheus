import 'dart:async';

import 'package:flutter/material.dart';

import '../application/data_export_controller.dart';

/// What an export says about how it went: the line under its entry, and whether
/// it is something to worry about.
typedef ExportStatus = ({String text, bool isProblem});

/// A Preferences entry that runs an export, says in a line what it is for, and
/// says what it did.
///
/// The JSON export and the backup ZIP are the same entry in everything but
/// what they are called, what they explain and what they say when they are
/// done, which is why they share this.
///
/// A progress indicator and no way to tap again while it runs: the library,
/// the playlists and the history are waited for, and a large library takes a
/// moment to build.
///
/// The result is a line under the entry rather than a snackbar. The entry
/// lives in a dialog, and a snackbar would show on the screen behind it,
/// dimmed by the barrier, and be gone in a few seconds, which is not how to
/// tell someone their backup is incomplete. The line stays until the next
/// run starts or the dialog closes.
class ExportActionTile extends StatefulWidget {
  /// Creates the tile.
  const ExportActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.explanation,
    required this.running,
    required this.run,
    required this.statusOf,
  });

  /// The icon at its start.
  final IconData icon;

  /// What the entry is called.
  final String title;

  /// The line under the title saying what the export is for.
  final String explanation;

  /// Whether a run is under way, which is what disables the entry.
  final bool running;

  /// Runs the export.
  final Future<DataExportResult> Function() run;

  /// What to say about [result], or `null` to say nothing: a cancelled save
  /// dialog is the owner's answer, not something to report.
  final ExportStatus? Function(DataExportResult result) statusOf;

  @override
  State<ExportActionTile> createState() => _ExportActionTileState();
}

class _ExportActionTileState extends State<ExportActionTile> {
  /// What the last run said.
  ExportStatus? _status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !widget.running,
      isThreeLine: true,
      leading: Icon(widget.icon),
      title: Text(widget.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.explanation),
          if (status != null)
            // A live region, so that a screen reader announces how it went
            // when the line appears, without the owner having to go and find
            // it.
            Semantics(
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
        ],
      ),
      trailing: widget.running
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => unawaited(_run()),
    );
  }

  Future<void> _run() async {
    // The last result is out of date the moment another run starts.
    setState(() => _status = null);

    final result = await widget.run();

    // The dialog can be closed while it runs; its result then has nowhere to
    // be said.
    if (!mounted) return;

    setState(() => _status = widget.statusOf(result));
  }
}
