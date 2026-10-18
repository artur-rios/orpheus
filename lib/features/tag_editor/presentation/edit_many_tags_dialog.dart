import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../autofill/domain/autofill_field.dart';
import '../../autofill/presentation/autofill_field_names.dart';
import '../../library/domain/music_entry.dart';
import '../../playback/presentation/music_display_name.dart';
import '../application/many_tag_edit_controller.dart';
import '../application/tag_edit_controller.dart' show UnwritableReason;
import '../domain/shared_tags.dart';
import '../domain/tag_edits.dart';
import 'tag_edit_messages.dart';

/// The form the tags several tracks share are edited in at once — an album's,
/// or an artist's.
///
/// Laid out as [EditTagsDialog] is: a dialog on a wide window, the whole
/// screen on a phone. Title and track number are left out: one value for
/// every track would almost always be wrong. Pops the number of files written
/// once a save is over, and `null` when the owner left before saving.
class EditManyTagsDialog extends ConsumerStatefulWidget {
  /// Creates the form.
  const EditManyTagsDialog({
    required this.entries,
    required this.label,
    super.key,
  });

  /// The tracks being edited.
  final List<MusicEntry> entries;

  /// What they are, as the owner picked them: the album's or artist's name.
  final String label;

  @override
  ConsumerState<EditManyTagsDialog> createState() => _EditManyTagsDialogState();
}

class _EditManyTagsDialogState extends ConsumerState<EditManyTagsDialog> {
  final Map<AutofillField, TextEditingController> _text = {
    for (final field in sharedTextFields) field: TextEditingController(),
  };
  CoverChoice _cover = const KeepCover();
  bool _coverNotImage = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the controller is being watched — kept
    // alive — before the files are read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(manyTagEditControllerProvider.notifier).load(widget.entries),
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

  /// Puts what the files share into the form.
  void _fill(SharedTags shared) {
    for (final MapEntry(key: field, value: controller) in _text.entries) {
      controller.text = sharedText(shared, field);
    }
    _cover = const KeepCover();
    _coverNotImage = false;
  }

  /// Whether [form] would change any file: `03` typed over a shared `3` is a
  /// change to the form and none to the files.
  bool _changesAnyFile(SharedTags shared, TagForm form) =>
      hasSharedChanges(shared, form) &&
      ref
          .read(manyTagEditControllerProvider.notifier)
          .files
          .any((file) => editsFor(file, shared, form).values.isNotEmpty);

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
    final state = ref.watch(manyTagEditControllerProvider);

    ref.listen(manyTagEditControllerProvider, (previous, next) {
      if (next.stage == ManyTagEditStage.editing &&
          previous?.stage == ManyTagEditStage.loading) {
        final shared = next.shared;
        if (shared != null) setState(() => _fill(shared));
      }
      if (next.stage == ManyTagEditStage.saved) {
        Navigator.of(context).pop(next.written);
      }
    });

    final shared = state.shared;
    final form = _form;
    final editing = state.stage == ManyTagEditStage.editing && shared != null;
    final problems = editing
        ? sharedNumberProblems(shared, form)
        : const <AutofillField, NumberProblem>{};
    final canSave =
        editing && problems.isEmpty && _changesAnyFile(shared, form);

    final title = Text(l10n.tagEditTitle);
    final subtitle = Text(
      l10n.tagEditManySubtitle(widget.label, widget.entries.length),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final body = switch ((state.stage, shared)) {
      (ManyTagEditStage.unwritable, _) => Text(
        state.unwritable == UnwritableReason.format
            ? l10n.autofillNothingWritable
            : l10n.autofillUnsafeTags,
      ),
      (_, final shared?) => _formView(l10n, state, shared, problems),
      _ => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.tagEditManyReading(state.done, state.total)),
          ],
        ),
      ),
    };
    final actions = _actions(l10n, state, canSave);

    final Widget dialog;
    if (Breakpoint.from(context) == Breakpoint.phone) {
      dialog = Dialog.fullscreen(
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
    } else {
      dialog = AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [title, subtitle],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: body),
        ),
        actions: actions,
      );
    }

    // Not while writing: closing mid-way would hide which files were
    // written. After a save, back closes as Close does, with the count.
    final results = state.stage == ManyTagEditStage.results;
    return PopScope<int>(
      canPop: state.stage != ManyTagEditStage.saving && !results,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && results) Navigator.of(context).pop(state.written);
      },
      child: dialog,
    );
  }

  Widget _formView(
    AppLocalizations l10n,
    ManyTagEditState state,
    SharedTags shared,
    Map<AutofillField, NumberProblem> problems,
  ) {
    final theme = Theme.of(context);
    final busy = state.stage != ManyTagEditStage.editing;
    final notWritable = [
      for (final field in [...sharedTextFields, AutofillField.cover])
        if (!shared.writable.contains(field)) autofillFieldName(l10n, field),
    ];
    const gap = SizedBox(height: AppSpacing.sm);

    Widget field(AutofillField f) => TextField(
      key: ValueKey(f),
      controller: _text[f],
      enabled: shared.writable.contains(f),
      readOnly: busy,
      keyboardType: numberFields.contains(f)
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: autofillFieldName(l10n, f),
        hintText: isMixed(shared, f) ? l10n.tagEditManyMixed : null,
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

    Widget song(MusicEntry entry, String why, {TextStyle? style}) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(musicTitleOf(entry, l10n)),
      subtitle: Text(why, style: style),
    );

    final error = TextStyle(color: theme.colorScheme.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.skipped.isNotEmpty) ...[
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(l10n.tagEditManySkipped(state.skipped.length)),
            children: [
              for (final skipped in state.skipped)
                song(skipped.entry, switch (skipped.reason) {
                  SkipReason.format => l10n.tagEditManySkippedFormat,
                  SkipReason.unsafe => l10n.tagEditManySkippedUnsafe,
                }),
            ],
          ),
          gap,
        ],
        _coverRow(l10n, shared, busy),
        gap,
        field(AutofillField.artist),
        gap,
        field(AutofillField.albumArtist),
        gap,
        field(AutofillField.album),
        gap,
        field(AutofillField.trackTotal),
        gap,
        pair(AutofillField.discNumber, AutofillField.discTotal),
        gap,
        field(AutofillField.year),
        gap,
        field(AutofillField.genre),
        gap,
        Text(l10n.tagEditManyOneAtATime),
        if (notWritable.isNotEmpty) ...[
          gap,
          Text(l10n.autofillNotWritableFields(notWritable.join(', '))),
        ],
        if (state.stage == ManyTagEditStage.saving) ...[
          gap,
          Text(l10n.tagEditManySaving(state.done, state.total)),
        ],
        if (state.stage == ManyTagEditStage.results) ...[
          gap,
          Text(
            state.failed.isEmpty
                ? l10n.tagEditManySaved(state.written)
                : l10n.tagEditManyPartly(state.written, state.failed.length),
            style: theme.textTheme.titleSmall,
          ),
          for (final failure in state.failed)
            song(
              failure.entry,
              writeOutcomeMessage(l10n, failure.outcome),
              style: error,
            ),
          for (final left in state.totalsLeft) ...[
            if (left.totals.contains(AutofillField.trackTotal))
              song(left.entry, l10n.tagEditManyTrackTotalLeft),
            if (left.totals.contains(AutofillField.discTotal))
              song(left.entry, l10n.tagEditManyDiscTotalLeft),
          ],
        ],
        if (state.refusal case final refusal?) ...[
          gap,
          TagEditAccessRefusal(refusal: refusal),
        ],
      ],
    );
  }

  Widget _coverRow(AppLocalizations l10n, SharedTags shared, bool busy) {
    final theme = Theme.of(context);
    final writable = shared.writable.contains(AutofillField.cover) && !busy;

    Widget picture(Uint8List bytes) => Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_outlined, size: 48),
    );
    final none = Icon(
      Icons.album_outlined,
      size: 48,
      semanticLabel: l10n.tagEditNoCover,
    );
    final shown = switch (_cover) {
      ReplaceCover(:final bytes) => picture(bytes),
      RemoveCover() => none,
      KeepCover() => switch (shared.cover) {
        Same(:final value?) => picture(value),
        Same() => none,
        Mixed() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_none, size: 40),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.tagEditManyMixedCovers,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      },
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: 96, child: shown),
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
                  // Also once a picture is picked, so the pick can be undone:
                  // over songs with no cover, removing it is keeping theirs.
                  TextButton(
                    onPressed:
                        writable &&
                            (shared.anyCover && _cover is! RemoveCover ||
                                _cover is ReplaceCover)
                        ? () => setState(() {
                            _cover = shared.anyCover
                                ? const RemoveCover()
                                : const KeepCover();
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
    ManyTagEditState state,
    bool canSave,
  ) {
    final material = MaterialLocalizations.of(context);
    final controller = ref.read(manyTagEditControllerProvider.notifier);

    switch (state.stage) {
      case ManyTagEditStage.unwritable:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(material.closeButtonLabel),
          ),
        ];
      case ManyTagEditStage.results:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(state.written),
            child: Text(material.closeButtonLabel),
          ),
          if (state.failed.any((failure) => failure.retryable))
            FilledButton(
              onPressed: () => unawaited(controller.retry()),
              child: Text(l10n.autofillTryAgain),
            ),
        ];
      case ManyTagEditStage.loading ||
          ManyTagEditStage.editing ||
          ManyTagEditStage.saving ||
          ManyTagEditStage.saved:
        final saving = state.stage == ManyTagEditStage.saving;

        return [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: Text(material.cancelButtonLabel),
          ),
          if (state.stage != ManyTagEditStage.loading)
            FilledButton(
              onPressed: canSave
                  ? () => unawaited(controller.save(_form))
                  : null,
              child: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.tagEditSave),
            ),
        ];
    }
  }
}
