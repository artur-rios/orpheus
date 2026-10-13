import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../autofill/domain/autofill_field.dart';
import '../../autofill/domain/tag_writer.dart';
import '../../library/domain/audio_file.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';

/// Where a tag edit is.
enum TagEditStage {
  /// Reading the file's tags.
  loading,

  /// The file cannot be edited; [TagEditState.unwritable] says why.
  unwritable,

  /// The owner is editing. [TagEditState.outcome] or
  /// [TagEditState.refusal] say why the last save did not land, if one did not.
  editing,

  /// Writing.
  saving,

  /// Written.
  saved,
}

/// Why a file cannot be edited.
enum UnwritableReason {
  /// Its format is not one Orpheus writes.
  format,

  /// Its format is, and its tags could not be read, or are of a shape the
  /// writer will not change safely.
  unsafe,
}

/// One tag edit.
class TagEditState {
  /// Creates a state.
  const TagEditState({
    this.stage = TagEditStage.loading,
    this.tags = FileTags.unwritable,
    this.unwritable,
    this.outcome,
    this.refusal,
  });

  /// Where it is.
  final TagEditStage stage;

  /// What the file held when it was read.
  final FileTags tags;

  /// Why it cannot be edited, where it cannot.
  final UnwritableReason? unwritable;

  /// What became of the last save, where it was not written.
  final WriteOutcome? outcome;

  /// Why the last save wrote nothing, where the owner refused access.
  final LibraryAccessDecision? refusal;

  /// A copy at [stage]. [outcome] and [refusal] clear unless passed: each
  /// describes one save.
  TagEditState copyWith({
    TagEditStage? stage,
    WriteOutcome? outcome,
    LibraryAccessDecision? refusal,
  }) => TagEditState(
    stage: stage ?? this.stage,
    tags: tags,
    unwritable: unwritable,
    outcome: outcome,
    refusal: refusal,
  );
}

/// Reads one track's tags, and writes the ones the owner changed.
///
/// Auto-disposed: it lives as long as the dialog watching it. Every await is
/// followed by a check that it still does — except that a write the owner
/// confirmed is finished, and followed by a rescan, whether or not the dialog
/// is still open.
class TagEditController extends Notifier<TagEditState> {
  static final Logger _log = Logger('tag-editor');

  MusicEntry? _entry;
  AudioFile? _read;
  bool _saving = false;

  @override
  TagEditState build() => const TagEditState();

  /// Reads [entry]'s tags to edit.
  Future<void> load(MusicEntry entry) {
    _entry = entry;

    return _inspect(entry);
  }

  /// Reads the same file again, dropping the owner's edits — after another
  /// program changed it.
  Future<void> reload() async {
    final entry = _entry;
    if (entry == null) return;

    await _inspect(entry);
  }

  /// Writes [edits], then rescans.
  ///
  /// One at a time: a second tap while the access prompt is up, or while the
  /// file is being written, would write it twice.
  Future<void> save(Map<AutofillField, Object?> edits) async {
    final entry = _entry;
    final read = _read;
    if (entry == null || read == null || edits.isEmpty || _saving) return;

    _saving = true;
    try {
      await _save(entry.file.path, read, edits);
    } finally {
      _saving = false;
    }
  }

  Future<void> _inspect(MusicEntry entry) async {
    final path = entry.file.path;
    _read = null;
    state = const TagEditState();

    if (!canWriteTagsTo(path)) {
      state = const TagEditState(
        stage: TagEditStage.unwritable,
        unwritable: UnwritableReason.format,
      );
      return;
    }

    try {
      // Stamped first: a file changed between the stamp and the read is
      // refused at the write, never written over.
      final stamp = await ref.read(fileStampsProvider).stamp(path);
      if (!ref.mounted) return;
      final tags = await ref.read(tagWriterProvider).inspect(path);
      if (!ref.mounted) return;

      if (tags.writable.isEmpty) {
        state = const TagEditState(
          stage: TagEditStage.unwritable,
          unwritable: UnwritableReason.unsafe,
        );
        return;
      }

      _read = stamp;
      state = TagEditState(stage: TagEditStage.editing, tags: tags);
    } on Object catch (error) {
      _log.warning('the tags of $path could not be read', error);
      if (!ref.mounted) return;
      state = const TagEditState(
        stage: TagEditStage.unwritable,
        unwritable: UnwritableReason.unsafe,
      );
    }
  }

  Future<void> _save(
    String path,
    AudioFile read,
    Map<AutofillField, Object?> edits,
  ) async {
    // All resolved now: once the dialog closes `ref` can no longer be read,
    // and a write the owner confirmed is still to be finished and followed by
    // a rescan.
    final access = ref.read(libraryAccessControllerProvider.notifier);
    final writer = ref.read(tagWriterProvider);
    final scan = ref.read(scanControllerProvider.notifier);

    state = state.copyWith(stage: TagEditStage.saving);

    final decision = await access.ensureWritable();
    if (!ref.mounted) return;
    if (!decision.isGranted) {
      state = state.copyWith(stage: TagEditStage.editing, refusal: decision);
      return;
    }

    final outcome = await writer.write(path, edits, expected: read);
    if (outcome == WriteOutcome.written) unawaited(scan.rescanSoon());
    if (!ref.mounted) return;

    state = outcome == WriteOutcome.written
        ? state.copyWith(stage: TagEditStage.saved)
        : state.copyWith(stage: TagEditStage.editing, outcome: outcome);
  }
}
