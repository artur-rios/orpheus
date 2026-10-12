import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/autofill_field.dart';
import 'autofill_field_names.dart';

/// The checklist an autofill starts from.
class AutofillFieldsDialog extends StatefulWidget {
  const AutofillFieldsDialog._({required this.initial, required this.anyWritable});

  /// What is ticked when it opens.
  final Set<AutofillField> initial;

  /// Whether any file in the selection can be written. Where none can, the
  /// dialog says so and there is nothing to find: looking a record up only
  /// to say its files cannot be changed would be a request for nothing.
  final bool anyWritable;

  /// Asks which tags to fill; `null` when the owner cancels.
  static Future<Set<AutofillField>?> ask(
    BuildContext context, {
    required Set<AutofillField> initial,
    required bool anyWritable,
  }) => showDialog<Set<AutofillField>>(
    context: context,
    builder: (_) => AutofillFieldsDialog._(initial: initial, anyWritable: anyWritable),
  );

  @override
  State<AutofillFieldsDialog> createState() => _AutofillFieldsDialogState();
}

class _AutofillFieldsDialogState extends State<AutofillFieldsDialog> {
  late final Set<AutofillField> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!widget.anyWritable) {
      return AlertDialog(
        title: Text(l10n.autofillFieldsTitle),
        content: Text(l10n.autofillNothingWritable),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillClose)),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.autofillFieldsTitle),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final field in AutofillField.values)
              CheckboxListTile(
                dense: true,
                value: _chosen.contains(field),
                title: Text(autofillFieldName(l10n, field)),
                subtitle: field == AutofillField.cover ? Text(l10n.autofillCoverNote) : null,
                onChanged: (ticked) => setState(
                  () => ticked == true ? _chosen.add(field) : _chosen.remove(field),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillCancel)),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, {..._chosen}),
          child: Text(l10n.autofillFind),
        ),
      ],
    );
  }
}
