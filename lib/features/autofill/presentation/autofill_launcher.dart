import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../application/autofill_controller.dart';
import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';
import 'autofill_fields_dialog.dart';

/// Asks which tags to fill, then opens the review screen for [entries].
Future<void> startAutofill(
  BuildContext context,
  WidgetRef ref,
  List<MusicEntry> entries, {
  required AutofillKind kind,
}) async {
  if (entries.isEmpty) return;

  // From the settings rather than from the controller: the controller is
  // auto-disposed, and the session it holds starts on the review screen.
  final remembered = AutofillField.decode(
    ref.read(settingsStoreProvider).getString(AutofillController.fieldsSettingsKey),
  );
  final fields = await AutofillFieldsDialog.ask(
    context,
    initial: remembered,
    anyWritable: entries.any((entry) => canWriteTagsTo(entry.file.path)),
  );
  if (fields == null || !context.mounted) return;

  // Task 12: push AutofillScreen(entries: entries, fields: fields, kind: kind).
}
