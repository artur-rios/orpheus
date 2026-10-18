import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../autofill/domain/autofill_field.dart';
import '../../autofill/domain/tag_writer.dart';
import '../../library/domain/audio_file.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../domain/shared_tags.dart';
import '../domain/tag_edits.dart';
import 'tag_edit_controller.dart' show UnwritableReason;

/// Where an edit over several tracks is.
enum ManyTagEditStage {
  /// Reading the files' tags.
  loading,

  /// None of the files can be edited; [ManyTagEditState.unwritable] says why.
  unwritable,

  /// The owner is editing. [ManyTagEditState.refusal] says why the last save
  /// wrote nothing, if it did not.
  editing,

  /// Writing.
  saving,

  /// Some pass left files failed or totals unwritten; the owner is told which.
  results,

  /// Every file is written or had nothing to write, and no total was left.
  saved,
}

/// Why a file is left alone.
enum SkipReason {
  /// Its format is not one Orpheus writes.
  format,

  /// Its format is, and its tags could not be read, or are of a shape the
  /// writer will not change safely.
  unsafe,
}

/// A file the form does not edit.
class SkippedTrack {
  /// Creates it.
  const SkippedTrack(this.entry, this.reason);

  /// The track.
  final MusicEntry entry;

  /// Why it is left alone.
  final SkipReason reason;
}

/// A file a save could not write.
class FailedTrack {
  /// Creates it.
  const FailedTrack(this.entry, this.outcome);

  /// The track.
  final MusicEntry entry;

  /// What became of its write.
  final WriteOutcome outcome;

  /// Whether trying again can help: not for a file this process may not
  /// write, or whose format cannot be.
  bool get retryable => switch (outcome) {
    WriteOutcome.inUse ||
    WriteOutcome.failed ||
    WriteOutcome.changedSinceRead => true,
    WriteOutcome.written ||
    WriteOutcome.unsupported ||
    WriteOutcome.denied => false,
  };
}

/// A file left holding a total without its number, which ID3 cannot say, and
/// so left as it was.
class TotalLeft {
  /// Creates it.
  const TotalLeft(this.entry, this.totals);

  /// The track.
  final MusicEntry entry;

  /// The totals (`trackTotal`, `discTotal`) not written.
  final Set<AutofillField> totals;
}

/// One edit over several tracks.
class ManyTagEditState {
  /// Creates a state.
  const ManyTagEditState({
    this.stage = ManyTagEditStage.loading,
    this.done = 0,
    this.total = 0,
    this.shared,
    this.skipped = const [],
    this.unwritable,
    this.written = 0,
    this.failed = const [],
    this.totalsLeft = const [],
    this.refusal,
    this.savedForm,
  });

  /// Where it is.
  final ManyTagEditStage stage;

  /// How many files the current read or save has got through.
  final int done;

  /// How many files the current read or save is over.
  final int total;

  /// What the files being edited hold in common; `null` until they are read.
  final SharedTags? shared;

  /// The files left alone.
  final List<SkippedTrack> skipped;

  /// Why none can be edited, where none can: unsafe if any was skipped as
  /// that.
  final UnwritableReason? unwritable;

  /// The files written, across every save so far.
  final int written;

  /// The files the last save could not write.
  final List<FailedTrack> failed;

  /// The totals left unwritten, across every save so far.
  final List<TotalLeft> totalsLeft;

  /// Why the last save wrote nothing, where the owner refused access.
  final LibraryAccessDecision? refusal;

  /// The form as saved; set from the first save on.
  final TagForm? savedForm;

  /// A copy. [refusal] clears unless passed: it describes one save.
  ManyTagEditState copyWith({
    ManyTagEditStage? stage,
    int? done,
    int? total,
    int? written,
    List<FailedTrack>? failed,
    List<TotalLeft>? totalsLeft,
    LibraryAccessDecision? refusal,
    TagForm? savedForm,
  }) => ManyTagEditState(
    stage: stage ?? this.stage,
    done: done ?? this.done,
    total: total ?? this.total,
    shared: shared,
    skipped: skipped,
    unwritable: unwritable,
    written: written ?? this.written,
    failed: failed ?? this.failed,
    totalsLeft: totalsLeft ?? this.totalsLeft,
    refusal: refusal,
    savedForm: savedForm ?? this.savedForm,
  );
}

/// A file being edited: what it was when read, and what it held.
class _Target {
  _Target(this.entry, this.stamp, this.tags);

  final MusicEntry entry;
  AudioFile stamp;
  FileTags tags;
}

/// Reads several tracks' tags, and writes what the owner changed in them.
///
/// Auto-disposed: it lives as long as the dialog watching it. A load stops
/// when the dialog goes, but a save the owner confirmed does not: every file
/// is written, and the library rescanned, whether or not the dialog is still
/// open. Only state updates are skipped.
class ManyTagEditController extends Notifier<ManyTagEditState> {
  static final Logger _log = Logger('tag-editor');

  /// The files being edited, by path, in library order.
  final Map<String, _Target> _targets = {};

  /// The files to stamp and inspect again before the next write: those that
  /// changed since they were read, and stay so until a read of them lands.
  ///
  /// Apart from what [ManyTagEditState.failed] reports, because a file whose
  /// read again threw is reported as failed and must still be read again on
  /// the next try, not written against the stamp it was refused for.
  final Set<String> _stale = {};
  bool _saving = false;

  @override
  ManyTagEditState build() => const ManyTagEditState();

  /// What each file being edited holds, as last read, in library order: what
  /// a form's edits are worked out against, file by file.
  List<FileTags> get files => [
    for (final target in _targets.values) target.tags,
  ];

  /// Reads [entries]' tags to edit, one after another.
  Future<void> load(List<MusicEntry> entries) async {
    _targets.clear();
    _stale.clear();
    final skipped = <SkippedTrack>[];
    final stamps = ref.read(fileStampsProvider);
    final writer = ref.read(tagWriterProvider);

    state = ManyTagEditState(total: entries.length);

    for (final (index, entry) in entries.indexed) {
      final path = entry.file.path;

      if (!canWriteTagsTo(path)) {
        skipped.add(SkippedTrack(entry, SkipReason.format));
      } else {
        try {
          // Stamped first: a file changed between the stamp and the read is
          // refused at the write, never written over.
          final stamp = await stamps.stamp(path);
          final tags = await writer.inspect(path);

          if (tags.writable.isEmpty) {
            skipped.add(SkippedTrack(entry, SkipReason.unsafe));
          } else {
            _targets[path] = _Target(entry, stamp, tags);
          }
        } on Object catch (error) {
          _log.warning('the tags of $path could not be read', error);
          skipped.add(SkippedTrack(entry, SkipReason.unsafe));
        }
      }

      if (!ref.mounted) return;
      state = ManyTagEditState(done: index + 1, total: entries.length);
    }

    if (_targets.isEmpty) {
      state = ManyTagEditState(
        stage: ManyTagEditStage.unwritable,
        total: entries.length,
        skipped: skipped,
        unwritable: skipped.any((track) => track.reason == SkipReason.unsafe)
            ? UnwritableReason.unsafe
            : UnwritableReason.format,
      );
      return;
    }

    state = ManyTagEditState(
      stage: ManyTagEditStage.editing,
      done: entries.length,
      total: entries.length,
      shared: SharedTags.of([
        for (final target in _targets.values) target.tags,
      ]),
      skipped: skipped,
    );
  }

  /// Writes what [form] changes into every file being edited, then rescans.
  ///
  /// One at a time: a second tap while the access prompt is up, or while the
  /// files are being written, would write them twice.
  Future<void> save(TagForm form) async {
    if (_saving || state.stage != ManyTagEditStage.editing) return;
    if (state.shared == null || _targets.isEmpty) return;

    await _pass(form, _targets.values.toList(), retrying: false);
  }

  /// Saves the form again over the files that failed in a way trying again
  /// can help. A file that changed since it was read is read again first.
  Future<void> retry() async {
    final form = state.savedForm;
    if (_saving || state.stage != ManyTagEditStage.results || form == null) {
      return;
    }

    final targets = [
      for (final failure in state.failed)
        if (failure.retryable) ?_targets[failure.entry.file.path],
    ];
    if (targets.isEmpty) return;

    await _pass(form, targets, retrying: true);
  }

  Future<void> _pass(
    TagForm form,
    List<_Target> targets, {
    required bool retrying,
  }) async {
    final shared = state.shared;
    if (shared == null) return;

    // All resolved now: once the dialog closes `ref` can no longer be read,
    // and a save the owner confirmed is still to be finished and followed by
    // a rescan.
    final access = ref.read(libraryAccessControllerProvider.notifier);
    final writer = ref.read(tagWriterProvider);
    final stamps = ref.read(fileStampsProvider);
    final scan = ref.read(scanControllerProvider.notifier);

    // What the earlier passes left: failures that stay listed, and the notes.
    final kept = [
      for (final failure in state.failed)
        if (!failure.retryable) failure,
    ];
    final totalsLeft = [...state.totalsLeft];
    var written = state.written;
    final failed = <FailedTrack>[];
    var wroteAny = false;

    _saving = true;
    try {
      state = state.copyWith(
        stage: ManyTagEditStage.saving,
        done: 0,
        total: targets.length,
        savedForm: form,
      );

      final LibraryAccessDecision decision;
      try {
        decision = await access.ensureWritable();
      } on Object catch (error) {
        // Nothing written, and the form must not be left saving with no way
        // to close it.
        _log.warning('write access could not be asked for', error);
        if (ref.mounted) {
          state = state.copyWith(
            stage: retrying
                ? ManyTagEditStage.results
                : ManyTagEditStage.editing,
          );
        }
        return;
      }
      if (!ref.mounted) return;
      if (!decision.isGranted) {
        state = state.copyWith(
          stage: retrying ? ManyTagEditStage.results : ManyTagEditStage.editing,
          refusal: decision,
        );
        return;
      }

      for (final (index, target) in targets.indexed) {
        final path = target.entry.file.path;

        if (_stale.contains(path)) {
          try {
            final stamp = await stamps.stamp(path);
            final tags = await writer.inspect(path);
            // Read: whatever the write does next, it is against this.
            _stale.remove(path);
            if (tags.writable.isEmpty) {
              // Changed into a tag the writer will not touch: no try again
              // can help, so it is listed as the form lists such a file.
              failed.add(FailedTrack(target.entry, WriteOutcome.unsupported));
              if (ref.mounted) state = state.copyWith(done: index + 1);
              continue;
            }
            target
              ..stamp = stamp
              ..tags = tags;
          } on Object catch (error) {
            _log.warning('the tags of $path could not be read again', error);
            failed.add(FailedTrack(target.entry, WriteOutcome.failed));
            if (ref.mounted) state = state.copyWith(done: index + 1);
            continue;
          }
        }

        final edits = editsFor(target.tags, shared, form);
        var outcome = WriteOutcome.written;
        if (edits.values.isNotEmpty) {
          try {
            outcome = await writer.write(
              path,
              edits.values,
              expected: target.stamp,
            );
          } on Object catch (error) {
            _log.warning('$path could not be written', error);
            outcome = WriteOutcome.failed;
          }
        }

        if (outcome == WriteOutcome.written) {
          if (edits.values.isNotEmpty) {
            written++;
            wroteAny = true;
          }
          if (edits.leftForMissingNumber.isNotEmpty) {
            totalsLeft.add(TotalLeft(target.entry, edits.leftForMissingNumber));
          }
        } else {
          if (outcome == WriteOutcome.changedSinceRead) _stale.add(path);
          failed.add(FailedTrack(target.entry, outcome));
        }

        if (ref.mounted) state = state.copyWith(done: index + 1);
      }

      if (wroteAny) unawaited(scan.rescanSoon());
      if (!ref.mounted) return;

      final allFailed = [...kept, ...failed];
      state = state.copyWith(
        stage: allFailed.isNotEmpty || totalsLeft.isNotEmpty
            ? ManyTagEditStage.results
            : ManyTagEditStage.saved,
        written: written,
        failed: allFailed,
        totalsLeft: totalsLeft,
      );
    } finally {
      _saving = false;
    }
  }
}
