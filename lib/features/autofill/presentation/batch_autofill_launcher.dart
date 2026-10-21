import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../library/application/library_folders_controller.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../../shell/presentation/confirmation_dialog.dart';
import '../application/autofill_controller.dart';
import '../application/batch_autofill_controller.dart';
import '../domain/autofill_field.dart';
import '../domain/batch_plan.dart';
import '../domain/tag_writer.dart';
import 'autofill_fields_dialog.dart';
import 'autofill_launcher.dart';
import 'batch_autofill_screen.dart';

/// Autofills [entries]: one song as UC-34's lone track, several as a batch.
///
/// A batch is one at a time. Where one is running or paused, its screen opens
/// instead; where a finished one still has records waiting for the owner, the
/// owner is asked before they are forgotten. Then the owner picks the tags and
/// confirms what will be looked up, and the batch starts and its screen opens.
Future<void> startBatchAutofill(
  BuildContext context,
  WidgetRef ref,
  List<MusicEntry> entries,
) async {
  if (entries.isEmpty) return;
  if (entries.length == 1) {
    return startAutofill(context, ref, entries, kind: AutofillKind.track);
  }

  // Read before the first question, which the widget that asked may not
  // outlast.
  final controller = ref.read(batchAutofillControllerProvider.notifier);
  final batch = ref.read(batchAutofillControllerProvider);
  final library =
      ref.read(musicLibraryControllerProvider).value?.entries ?? const [];
  final access = ref.read(libraryAccessControllerProvider.notifier);
  final remembered = AutofillField.decode(
    ref
        .read(settingsStoreProvider)
        .getString(AutofillController.fieldsSettingsKey),
  );

  switch (batch.stage) {
    case BatchStage.running || BatchStage.paused:
      return BatchAutofillScreen.show(context);
    case BatchStage.finished when batch.needYou > 0:
      final l10n = AppLocalizations.of(context);
      final replace = await ConfirmationDialog.ask(
        context,
        title: l10n.autofillBatchReplaceTitle,
        body: l10n.autofillBatchReplaceBody(batch.needYou),
        confirmLabel: l10n.autofillBatchReplaceConfirm,
      );
      if (!replace || !context.mounted) return;
    case BatchStage.idle || BatchStage.finished:
      break;
  }

  final fields = await AutofillFieldsDialog.ask(
    context,
    initial: remembered,
    anyWritable: entries.any((entry) => canWriteTagsTo(entry.file.path)),
  );
  if (fields == null || !context.mounted) return;

  final plan = planBatch(entries, library);
  if (plan.units.isEmpty) return;

  final l10n = AppLocalizations.of(context);
  final skipped = plan.notWritable.length;
  final confirmed = await ConfirmationDialog.ask(
    context,
    title: l10n.autofillBatchConfirmTitle(plan.songCount),
    body: [
      l10n.autofillBatchConfirmBody(
        plan.units.length,
        estimatedMinutes(plan, fields),
      ),
      if (skipped > 0) l10n.autofillBatchConfirmSkipped(skipped),
    ].join(' '),
    confirmLabel: l10n.autofillBatchStart,
  );
  if (!confirmed || !context.mounted) return;

  final started = await controller.start(plan, fields);
  if (!context.mounted) return;

  if (started) return BatchAutofillScreen.show(context);

  final refusal = ref.read(batchAutofillControllerProvider).refusal;
  if (refusal != null) _refuse(context, access, refusal);
}

/// Says write access was refused, and offers the system settings where the
/// refusal is for good.
void _refuse(
  BuildContext context,
  LibraryAccessController access,
  LibraryAccessDecision refusal,
) {
  final l10n = AppLocalizations.of(context);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.autofillAccessRefused),
      action: refusal == LibraryAccessDecision.deniedPermanently
          ? SnackBarAction(
              label: l10n.autofillOpenSettings,
              onPressed: () => unawaited(access.openSettings()),
            )
          : null,
    ),
  );
}
