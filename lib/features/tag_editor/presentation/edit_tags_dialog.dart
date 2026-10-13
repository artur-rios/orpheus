import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../autofill/domain/autofill_field.dart';
import '../../autofill/domain/tag_writer.dart';
import '../../autofill/presentation/autofill_field_names.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../../playback/presentation/music_display_name.dart';
import '../application/tag_edit_controller.dart';
import '../domain/tag_edits.dart';

/// The form one track's tags are edited in by hand.
///
/// A dialog on a wide window and the whole screen on a phone, where a dialog
/// with ten fields in it would leave the keyboard nowhere to go. Pops `true`
/// once the edit was written, and nothing otherwise.
class EditTagsDialog extends ConsumerStatefulWidget {
  /// Creates the form.
  const EditTagsDialog({required this.entry, super.key});

  /// The track being edited.
  final MusicEntry entry;

  @override
  ConsumerState<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends ConsumerState<EditTagsDialog> {
  final Map<AutofillField, TextEditingController> _text = {
    for (final field in editableTextFields) field: TextEditingController(),
  };
  CoverChoice _cover = const KeepCover();
  bool _coverNotImage = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the controller is being watched — kept
    // alive — before the file is read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(tagEditControllerProvider.notifier).load(widget.entry),
      );
    });
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TagForm get _form => TagForm(
    text: {for (final MapEntry(:key, :value) in _text.entries) key: value.text},
    cover: _cover,
  );

  /// Puts what the file holds into the form, dropping any edit.
  void _fill(FileTags tags) {
    for (final MapEntry(key: field, value: controller) in _text.entries) {
      controller.text = shownText(tags, field);
    }
    _cover = const KeepCover();
    _coverNotImage = false;
  }

  Future<void> _chooseCover() async {
    final bytes = await ref.read(coverPickerProvider).pickImage();
    if (bytes == null || !mounted) return;

    setState(() {
      _coverNotImage = !isSupportedCover(bytes);
      if (!_coverNotImage) _cover = ReplaceCover(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tagEditControllerProvider);

    ref.listen(tagEditControllerProvider, (previous, next) {
      // Filled each time the file has just been read — first, and after
      // Reload — and never after a save that did not land, which keeps the
      // owner's edits.
      if (next.stage == TagEditStage.editing &&
          previous?.stage == TagEditStage.loading) {
        setState(() => _fill(next.tags));
      }
      if (next.stage == TagEditStage.saved) Navigator.of(context).pop(true);
    });

    final editing = state.stage == TagEditStage.editing;
    final form = _form;
    final problems = editing
        ? numberProblems(state.tags, form)
        : const <AutofillField, NumberProblem>{};
    final canSave =
        editing &&
        state.outcome != WriteOutcome.changedSinceRead &&
        problems.isEmpty &&
        tagEdits(state.tags, form).isNotEmpty;

    final title = Text(l10n.tagEditTitle);
    final subtitle = Text(
      musicTitleOf(widget.entry, l10n),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final body = switch (state.stage) {
      TagEditStage.loading => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      TagEditStage.unwritable => Text(
        state.unwritable == UnwritableReason.format
            ? l10n.autofillNothingWritable
            : l10n.autofillUnsafeTags,
      ),
      _ => _formView(l10n, state, problems),
    };
    final actions = _actions(l10n, state, canSave);

    if (Breakpoint.from(context) == Breakpoint.phone) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(leading: const CloseButton(), title: title),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              subtitle,
              const SizedBox(height: AppSpacing.md),
              body,
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: actions,
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [title, subtitle],
      ),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: body)),
      actions: actions,
    );
  }

  Widget _formView(
    AppLocalizations l10n,
    TagEditState state,
    Map<AutofillField, NumberProblem> problems,
  ) {
    final theme = Theme.of(context);
    final tags = state.tags;
    final busy = state.stage != TagEditStage.editing;
    final notWritable = [
      for (final field in AutofillField.values)
        if (!tags.writable.contains(field)) autofillFieldName(l10n, field),
    ];
    const gap = SizedBox(height: AppSpacing.sm);

    Widget field(AutofillField f) => TextField(
      key: ValueKey(f),
      controller: _text[f],
      enabled: tags.writable.contains(f),
      readOnly: busy,
      keyboardType: numberFields.contains(f)
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: autofillFieldName(l10n, f),
        errorText: switch (problems[f]) {
          null => null,
          NumberProblem.notAWholeNumber => l10n.tagEditWholeNumber,
          NumberProblem.yearOutOfRange => l10n.tagEditYearRange,
          NumberProblem.totalWithoutNumber => l10n.tagEditNumberForTotal,
        },
      ),
      onChanged: (_) => setState(() {}),
    );

    Widget pair(AutofillField left, AutofillField right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field(left)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: field(right)),
      ],
    );

    final error = TextStyle(color: theme.colorScheme.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _coverRow(l10n, tags, busy),
        gap,
        field(AutofillField.title),
        gap,
        field(AutofillField.artist),
        gap,
        field(AutofillField.albumArtist),
        gap,
        field(AutofillField.album),
        gap,
        pair(AutofillField.trackNumber, AutofillField.trackTotal),
        gap,
        pair(AutofillField.discNumber, AutofillField.discTotal),
        gap,
        field(AutofillField.year),
        gap,
        field(AutofillField.genre),
        if (notWritable.isNotEmpty) ...[
          gap,
          Text(l10n.autofillNotWritableFields(notWritable.join(', '))),
        ],
        if (state.outcome case final outcome?) ...[
          gap,
          Text(_outcomeMessage(l10n, outcome), style: error),
        ],
        if (state.refusal case final refusal?) ...[
          gap,
          Text(l10n.autofillAccessRefused, style: error),
          if (refusal == LibraryAccessDecision.deniedPermanently)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => unawaited(
                  ref
                      .read(libraryAccessControllerProvider.notifier)
                      .openSettings(),
                ),
                child: Text(l10n.autofillOpenSettings),
              ),
            ),
        ],
      ],
    );
  }

  Widget _coverRow(AppLocalizations l10n, FileTags tags, bool busy) {
    final theme = Theme.of(context);
    final writable = tags.writable.contains(AutofillField.cover) && !busy;
    final Uint8List? shown = switch (_cover) {
      KeepCover() => tags.cover,
      RemoveCover() => null,
      ReplaceCover(:final bytes) => bytes,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 96,
          child: shown == null
              ? Icon(
                  Icons.album_outlined,
                  size: 48,
                  semanticLabel: l10n.tagEditNoCover,
                )
              : Image.memory(
                  shown,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 48),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                autofillFieldName(l10n, AutofillField.cover),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: Text(l10n.tagEditChooseCover),
                    onPressed: writable
                        ? () => unawaited(_chooseCover())
                        : null,
                  ),
                  TextButton(
                    onPressed: writable && shown != null
                        ? () => setState(() {
                            _cover = const RemoveCover();
                            _coverNotImage = false;
                          })
                        : null,
                    child: Text(l10n.tagEditRemoveCover),
                  ),
                ],
              ),
              if (_coverNotImage)
                Text(
                  l10n.tagEditCoverNotImage,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(
    AppLocalizations l10n,
    TagEditState state,
    bool canSave,
  ) {
    final material = MaterialLocalizations.of(context);
    final controller = ref.read(tagEditControllerProvider.notifier);

    if (state.stage == TagEditStage.unwritable) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.closeButtonLabel),
        ),
      ];
    }

    final retry =
        state.outcome == WriteOutcome.inUse ||
        state.outcome == WriteOutcome.failed;

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(material.cancelButtonLabel),
      ),
      if (state.outcome == WriteOutcome.changedSinceRead)
        TextButton(
          onPressed: () => unawaited(controller.reload()),
          child: Text(l10n.tagEditReload),
        ),
      if (state.stage != TagEditStage.loading)
        FilledButton(
          onPressed: canSave
              ? () => unawaited(controller.save(tagEdits(state.tags, _form)))
              : null,
          child: state.stage == TagEditStage.saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(retry ? l10n.autofillTryAgain : l10n.tagEditSave),
        ),
    ];
  }

  String _outcomeMessage(AppLocalizations l10n, WriteOutcome outcome) =>
      switch (outcome) {
        WriteOutcome.changedSinceRead => l10n.autofillOutcomeChanged,
        WriteOutcome.inUse => l10n.autofillOutcomeInUse,
        WriteOutcome.denied => l10n.autofillOutcomeDenied,
        // A kind of file Orpheus writes, whose tag the editor refused.
        WriteOutcome.unsupported => l10n.autofillUnsafeTags,
        _ => l10n.autofillOutcomeFailed,
      };
}
