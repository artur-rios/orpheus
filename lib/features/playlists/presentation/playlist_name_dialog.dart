import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/playlist.dart';

/// The dialog that asks what a playlist is called, for a new one or a rename.
///
/// It answers only a name [validPlaylistName] accepts: a blank one is refused
/// here, with the reason under the field, rather than reaching a controller
/// that would have to throw it back.
class PlaylistNameDialog extends StatefulWidget {
  /// Creates the dialog.
  const PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
    super.key,
  });

  /// What the dialog is for: *New playlist*, *Rename playlist*.
  final String title;

  /// The word on the confirming button.
  final String confirmLabel;

  /// What the field starts with: the name a renamed playlist has now.
  final String initialName;

  /// Asks, and answers the name trimmed — or `null` when the owner cancelled.
  static Future<String?> ask(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialName = '',
  }) => showDialog<String>(
    context: context,
    builder: (context) => PlaylistNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );

  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  // Selected whole, so that a rename is typed straight over the old name and
  // an arrow key keeps it for editing.
  late final TextEditingController _text = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.initialName,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      ),
    ),
  );

  bool _refused = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final name = validPlaylistName(_text.text);
    if (name == null) {
      setState(() => _refused = true);

      return;
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: l10n.playlistNameLabel,
          errorText: _refused ? l10n.playlistNameRequired : null,
        ),
        // The reason goes once the owner starts to answer it.
        onChanged: (_) {
          if (_refused) setState(() => _refused = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
