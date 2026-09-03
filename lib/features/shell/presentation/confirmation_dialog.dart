import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';

/// The one confirmation dialog.
///
/// One, rather than a hand-built `AlertDialog` at each call site, so that
/// every question this application asks is worded, laid out and dismissed the
/// same way — and so that "the destructive button is the one that is not
/// focused" is a property of the application rather than a habit.
class ConfirmationDialog extends StatelessWidget {
  /// Creates the dialog.
  const ConfirmationDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    super.key,
  });

  /// The question.
  final String title;

  /// What confirming will actually do.
  final String body;

  /// The word on the confirming button.
  final String confirmLabel;

  /// Asks, and answers what the owner said.
  ///
  /// `false` for a dialog dismissed with the escape key or a tap outside it,
  /// which is the same answer as cancelling — a question nobody answered is
  /// not a yes.
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmationDialog(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          // Focused, and deliberately the safe one: a dialog answered by
          // whoever pressed return without reading it should do nothing.
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
