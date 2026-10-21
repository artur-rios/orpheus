import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../domain/autofill_field.dart';
import '../domain/batch_plan.dart';
import '../domain/confidence.dart';
import '../domain/matching.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';
import 'autofill_controller.dart';
import 'release_fetch.dart';

/// Where a batch autofill is.
enum BatchStage {
  /// Nothing started, or the last batch cleared.
  idle,

  /// Looking units up and writing the confident ones.
  running,

  /// Stopped by MusicBrainz being out of reach, until the owner tries again
  /// or stops.
  paused,

  /// Every unit has an outcome; [BatchAutofillState.outcomes] says which.
  finished,
}

/// What became of one unit of a batch.
enum UnitOutcomeKind {
  /// Confident, and its changes written to at least one of its files.
  updated,

  /// Confident, and nothing to change.
  alreadyRight,

  /// Not sure enough: kept for the owner, nothing written.
  doubtful,

  /// The search answered nothing.
  notFound,

  /// MusicBrainz could not be reached, even on the second try.
  unreachable,

  /// None of its songs can be changed safely, so it was not looked up.
  notWritable,

  /// Could not be looked up or written: MusicBrainz answered something that
  /// could not be read, every write of a confident unit was refused, or
  /// something unforeseen went wrong with it.
  failed,

  /// The owner stopped the batch before it was reached.
  notLookedUp,
}

/// One unit's outcome, and what was found for it.
class UnitOutcome {
  /// Creates an outcome.
  const UnitOutcome({
    required this.unit,
    required this.kind,
    this.doubt,
    this.release,
    this.proposals = const [],
    this.blocked = const [],
    this.writes = const {},
    this.reviewed = false,
    this.coverUnavailable = false,
  });

  /// The record or lone track.
  final BatchUnit unit;

  /// What became of it.
  final UnitOutcomeKind kind;

  /// Why it is kept for the owner, where it is [UnitOutcomeKind.doubtful].
  final Doubtful? doubt;

  /// The release proposed from, where one was found.
  final ReleaseCandidate? release;

  /// The proposals of the files whose write can be tried again: those that
  /// were in use or failed.
  ///
  /// Nothing else is kept once the unit is decided — a chosen cover puts two
  /// pictures in every proposal, which a whole library's worth would not fit
  /// in memory. A doubtful unit keeps none: its review looks the record up
  /// again.
  final List<FileProposal> proposals;

  /// The songs of the unit that its proposals blocked as a whole, because no
  /// tag can be written to them safely.
  final List<MusicEntry> blocked;

  /// How each written file went, by path, including the ones that were not.
  final Map<String, WriteOutcome> writes;

  /// Whether the owner has reviewed it since, in the review screen.
  final bool reviewed;

  /// Whether the cover was chosen and could not be downloaded: the other
  /// changes stand without it.
  final bool coverUnavailable;

  /// The songs of this unit no tag can be written to safely, which its
  /// writes leave out.
  Iterable<MusicEntry> get blockedSongs =>
      kind == UnitOutcomeKind.notWritable ? unit.songs : blocked;

  /// A copy with the given changes.
  UnitOutcome copyWith({
    UnitOutcomeKind? kind,
    List<FileProposal>? proposals,
    Map<String, WriteOutcome>? writes,
    bool? reviewed,
  }) => UnitOutcome(
    unit: unit,
    kind: kind ?? this.kind,
    doubt: doubt,
    release: release,
    proposals: proposals ?? this.proposals,
    blocked: blocked,
    writes: writes ?? this.writes,
    reviewed: reviewed ?? this.reviewed,
    coverUnavailable: coverUnavailable,
  );
}

/// One batch autofill, as the batch screen and the shell's indicator show it.
class BatchAutofillState {
  /// Creates a state.
  const BatchAutofillState({
    this.stage = BatchStage.idle,
    this.plan,
    this.fields = const {},
    this.done = 0,
    this.outcomes = const [],
    this.refusal,
    this.stoppedEarly = false,
    this.stopping = false,
    this.seen = false,
  });

  /// Where it is.
  final BatchStage stage;

  /// What is being looked up, or `null` before a batch starts.
  final BatchPlan? plan;

  /// The tags the owner chose.
  final Set<AutofillField> fields;

  /// How many units have been looked up to an outcome so far.
  final int done;

  /// Each unit's outcome, in plan order, for the units that have one.
  final List<UnitOutcome> outcomes;

  /// Why nothing started, where the owner refused write access.
  final LibraryAccessDecision? refusal;

  /// Whether the owner stopped the batch with units still to look up.
  final bool stoppedEarly;

  /// Whether the owner has asked a running batch to stop, and it is finishing
  /// the unit in flight first.
  final bool stopping;

  /// Whether the owner has seen the finished batch's summary.
  final bool seen;

  /// How many units were written.
  int get updated => _count(UnitOutcomeKind.updated);

  /// How many units are doubtful and not yet reviewed.
  int get needYou => outcomes
      .where((o) => o.kind == UnitOutcomeKind.doubtful && !o.reviewed)
      .length;

  /// How many units had nothing to change.
  int get alreadyRight => _count(UnitOutcomeKind.alreadyRight);

  /// How many units the search found nothing for.
  int get notFound => _count(UnitOutcomeKind.notFound);

  /// The batch's songs no tag can be written to safely: those of a format
  /// that cannot be written, the songs of the units none of whose songs could
  /// be changed, and the songs left out of the other units' writes for the
  /// same reason.
  List<MusicEntry> get notWritableSongs => [
    ...?plan?.notWritable,
    for (final outcome in outcomes) ...outcome.blockedSongs,
  ];

  /// What was left alone: the [notWritableSongs], and the units that failed.
  int get skipped => notWritableSongs.length + _count(UnitOutcomeKind.failed);

  /// Whether the shell should show the batch: while it runs or is paused,
  /// and once finished until its summary has been seen and for as long as
  /// doubtful units wait for the owner.
  bool get showsIndicator => switch (stage) {
    BatchStage.running || BatchStage.paused => true,
    BatchStage.finished => !seen || needYou > 0,
    BatchStage.idle => false,
  };

  int _count(UnitOutcomeKind kind) =>
      outcomes.where((outcome) => outcome.kind == kind).length;

  /// A copy with the given changes. [refusal] clears unless passed: it
  /// describes a start that did not happen.
  BatchAutofillState copyWith({
    BatchStage? stage,
    int? done,
    List<UnitOutcome>? outcomes,
    LibraryAccessDecision? refusal,
    bool? stoppedEarly,
    bool? stopping,
    bool? seen,
  }) => BatchAutofillState(
    stage: stage ?? this.stage,
    plan: plan,
    fields: fields,
    done: done ?? this.done,
    outcomes: outcomes ?? this.outcomes,
    refusal: refusal,
    stoppedEarly: stoppedEarly ?? this.stoppedEarly,
    stopping: stopping ?? this.stopping,
    seen: seen ?? this.seen,
  );
}

/// A unit waiting its turn, and how many lookups of it MusicBrainz has not
/// answered.
class _Pending {
  const _Pending(this.index, {this.misses = 0});

  /// Its place in the plan.
  final int index;

  /// How many times it could not be looked up.
  final int misses;
}

/// What a lookup found for a unit, before anything is written.
typedef _Found = ({
  Confidence confidence,
  ReleaseCandidate release,
  List<FileProposal> proposals,
  bool coverUnavailable,
});

/// Walks a batch one unit at a time: looks each up, judges it, writes the
/// confident ones and keeps the doubtful ones for the owner.
///
/// Kept alive rather than auto-disposed, because a batch outlives its screen:
/// the owner starts it, closes the screen and goes on using Orpheus, and
/// comes back to it from the shell. One batch at a time.
///
/// A lookup MusicBrainz does not answer is tried once more after the unit
/// that follows; three such lookups in a row pause the batch, so a lost
/// connection does not burn through the library as failures. The rescan is
/// asked for at most once a minute while files are being written, and once
/// more when the batch stops if anything was written since.
class BatchAutofillController extends Notifier<BatchAutofillState> {
  static final Logger _log = Logger('autofill');

  /// How many lookups in a row MusicBrainz may leave unanswered before the
  /// batch pauses.
  static const int _missesBeforePause = 3;

  /// How long writes go on before the library is rescanned again.
  static const Duration _rescanEvery = Duration(minutes: 1);

  List<_Pending> _queue = [];
  List<UnitOutcome?> _outcomes = [];
  int _missesInARow = 0;
  bool _stopping = false;
  bool _starting = false;
  bool _retrying = false;
  DateTime? _lastRescan;
  bool _writtenSinceRescan = false;
  Future<void>? _run;
  Future<void>? _retry;

  /// Bumped whenever the batch is replaced or cleared, so a retry still
  /// writing does not report into the batch that took its place.
  int _generation = 0;

  @override
  BatchAutofillState build() => const BatchAutofillState();

  /// Starts a batch over [plan] for [fields], and answers whether it started.
  ///
  /// A batch running or paused answers `false` and is left as it is. [fields]
  /// are kept as the remembered choice, and write access is asked for once,
  /// here: a refusal starts nothing, leaves any finished batch as it was, and
  /// is kept in [BatchAutofillState.refusal]. Otherwise the batch replaces any
  /// finished one, and runs without being waited for.
  Future<bool> start(BatchPlan plan, Set<AutofillField> fields) async {
    if (_starting || _isActive) return false;

    _starting = true;
    try {
      await _remember(fields);
      final access = await ref
          .read(libraryAccessControllerProvider.notifier)
          .ensureWritable();
      if (!ref.mounted) return false;
      if (!access.isGranted) {
        state = state.copyWith(refusal: access);
        return false;
      }

      _generation++;
      _queue = [for (var i = 0; i < plan.units.length; i++) _Pending(i)];
      _outcomes = List.filled(plan.units.length, null);
      _missesInARow = 0;
      _stopping = false;
      _lastRescan = null;
      _writtenSinceRescan = false;
      state = BatchAutofillState(
        stage: BatchStage.running,
        plan: plan,
        fields: fields,
      );
      _run = _walk();

      return true;
    } finally {
      _starting = false;
    }
  }

  /// Stops after the unit being looked up or written, saying meanwhile that
  /// it is [BatchAutofillState.stopping]; the units not reached are reported
  /// as not looked up. A paused batch stops at once.
  void stop() {
    switch (state.stage) {
      case BatchStage.running:
        if (_stopping) return;
        _stopping = true;
        state = state.copyWith(stopping: true);
      case BatchStage.paused:
        _stopping = true;
        _finish();
      case BatchStage.idle || BatchStage.finished:
        return;
    }
  }

  /// Goes on with a paused batch, from the unit that paused it. The run is
  /// not waited for.
  Future<void> resume() async {
    if (state.stage != BatchStage.paused) return;

    _missesInARow = 0;
    _stopping = false;
    state = state.copyWith(stage: BatchStage.running, stopping: false);
    _run = _walk();
  }

  /// Writes again the files of a finished batch that were in use or failed.
  Future<void> retryFailed() async {
    if (state.stage != BatchStage.finished || _retrying) return;

    final retry = _rewrite(_generation);
    _retry = retry;
    await retry;
  }

  /// Marks [unit] as reviewed by the owner: it no longer needs them.
  void markReviewed(BatchUnit unit) {
    var changed = false;
    for (var i = 0; i < _outcomes.length; i++) {
      final outcome = _outcomes[i];
      if (outcome == null || outcome.reviewed || outcome.unit.key != unit.key) {
        continue;
      }

      _outcomes[i] = outcome.copyWith(reviewed: true);
      changed = true;
    }

    if (changed) state = state.copyWith(outcomes: _listed());
  }

  /// Notes that the owner has seen the finished batch's summary.
  void markSeen() {
    if (state.stage != BatchStage.finished || state.seen) return;

    state = state.copyWith(seen: true);
  }

  /// Forgets a finished batch and its doubtful units; nothing is written. A
  /// batch running or paused is left as it is.
  void clear() {
    if (_isActive) return;

    _generation++;
    _queue = [];
    _outcomes = [];
    state = const BatchAutofillState();
  }

  /// Completes once neither the run nor a retry is going.
  @visibleForTesting
  Future<void> get settled async {
    await _run;
    await _retry;
  }

  bool get _isActive =>
      state.stage == BatchStage.running || state.stage == BatchStage.paused;

  Future<void> _walk() async {
    final plan = state.plan!;
    final fields = state.fields;

    while (_queue.isNotEmpty && !_stopping) {
      final pending = _queue.removeAt(0);
      final unit = plan.units[pending.index];

      UnitOutcome? outcome;
      try {
        outcome = await _process(unit, fields);
      } on Object catch (error, stack) {
        // One unit's failure must not stop the others, nor leave the batch
        // running for ever.
        if (!ref.mounted) return;
        _log.warning('a batch autofill unit failed', error, stack);
        outcome = UnitOutcome(unit: unit, kind: UnitOutcomeKind.failed);
      }
      if (outcome == null || !ref.mounted) return;

      if (outcome.kind == UnitOutcomeKind.unreachable) {
        final missed = _Pending(pending.index, misses: pending.misses + 1);
        _missesInARow++;
        // A stop asked for meanwhile wins over the pause: the owner wants the
        // batch over, and this unit is reported as could not be looked up.
        if (_missesInARow >= _missesBeforePause && !_stopping) {
          _queue.insert(0, missed);
          state = state.copyWith(stage: BatchStage.paused);
          _rescanIfWritten();
          return;
        }
        if (missed.misses == 1) {
          _queue.insert(_queue.isEmpty ? 0 : 1, missed);
          continue;
        }
      } else if (outcome.kind != UnitOutcomeKind.notWritable) {
        // Answered, whatever the answer: MusicBrainz is there. A unit not
        // looked up says nothing either way.
        _missesInARow = 0;
      }

      _outcomes[pending.index] = outcome;
      state = state.copyWith(done: state.done + 1, outcomes: _listed());
      if (outcome.writes.containsValue(WriteOutcome.written)) _wrote();
    }

    _finish();
  }

  /// Ends the batch: what is still queued is reported — as could not be
  /// looked up where MusicBrainz already failed to answer for it, else as not
  /// looked up — and the rescan asked for if anything was written since the
  /// last.
  void _finish() {
    final unreached = _queue;
    _queue = [];
    final plan = state.plan!;
    for (final pending in unreached) {
      _outcomes[pending.index] = UnitOutcome(
        unit: plan.units[pending.index],
        kind: pending.misses > 0
            ? UnitOutcomeKind.unreachable
            : UnitOutcomeKind.notLookedUp,
      );
    }

    state = state.copyWith(
      stage: BatchStage.finished,
      outcomes: _listed(),
      stoppedEarly: _stopping && unreached.isNotEmpty,
      stopping: false,
      seen: false,
    );
    _rescanIfWritten();
  }

  /// Looks [unit] up, judges it and writes it where it is confident; `null`
  /// where the container went meanwhile.
  Future<UnitOutcome?> _process(
    BatchUnit unit,
    Set<AutofillField> fields,
  ) async {
    final writer = ref.read(tagWriterProvider);
    final tags = <String, FileTags>{};
    for (final song in unit.songs) {
      tags[song.file.path] = await _inspect(writer, song.file.path);
      if (!ref.mounted) return null;
    }
    if (tags.values.every((t) => t.writable.isEmpty)) {
      return UnitOutcome(unit: unit, kind: UnitOutcomeKind.notWritable);
    }

    final _Found? found;
    try {
      found = switch (unit.kind) {
        BatchUnitKind.record => await _findRecord(unit, fields, tags),
        BatchUnitKind.track => await _findTrack(unit, fields, tags),
      };
    } on MetadataSourceException catch (error) {
      return UnitOutcome(
        unit: unit,
        kind: switch (error.kind) {
          MetadataSourceFailure.unreachable ||
          MetadataSourceFailure.rateLimited => UnitOutcomeKind.unreachable,
          MetadataSourceFailure.malformed => UnitOutcomeKind.failed,
        },
      );
    }
    if (!ref.mounted) return null;
    if (found == null) {
      return UnitOutcome(unit: unit, kind: UnitOutcomeKind.notFound);
    }

    final (:confidence, :release, :proposals, :coverUnavailable) = found;
    final blocked = [
      for (final proposal in proposals)
        if (proposal.blockedBecause == ProposalBlock.unwritableFormat ||
            proposal.blockedBecause == ProposalBlock.unsafeTags)
          proposal.entry,
    ];
    if (confidence is Doubtful) {
      return UnitOutcome(
        unit: unit,
        kind: UnitOutcomeKind.doubtful,
        doubt: confidence,
        release: release,
        blocked: blocked,
        coverUnavailable: coverUnavailable,
      );
    }

    final changed = [
      for (final proposal in proposals)
        if (proposal.acceptedCount > 0) proposal,
    ];
    if (changed.isEmpty) {
      return UnitOutcome(
        unit: unit,
        kind: UnitOutcomeKind.alreadyRight,
        release: release,
        blocked: blocked,
        coverUnavailable: coverUnavailable,
      );
    }

    final writes = await _write(changed);
    if (writes == null) return null;

    return UnitOutcome(
      unit: unit,
      kind: _writtenOrFailed(writes),
      release: release,
      proposals: _toRetry(changed, writes),
      blocked: blocked,
      writes: writes,
      coverUnavailable: coverUnavailable,
    );
  }

  /// The proposals of [proposals] whose file [writes] says can be written
  /// again: all a retry needs, and all that is kept.
  static List<FileProposal> _toRetry(
    List<FileProposal> proposals,
    Map<String, WriteOutcome> writes,
  ) => [
    for (final proposal in proposals)
      if (_retryable(writes[proposal.entry.file.path])) proposal,
  ];

  /// [UnitOutcomeKind.updated] where [writes] reached at least one file, and
  /// [UnitOutcomeKind.failed] where every one was refused.
  static UnitOutcomeKind _writtenOrFailed(Map<String, WriteOutcome> writes) =>
      writes.containsValue(WriteOutcome.written)
      ? UnitOutcomeKind.updated
      : UnitOutcomeKind.failed;

  /// The best release for the record [unit], searched, ranked and assigned
  /// over all of its library songs, and proposed for its batch songs only.
  Future<_Found?> _findRecord(
    BatchUnit unit,
    Set<AutofillField> fields,
    Map<String, FileTags> tags,
  ) async {
    final source = ref.read(metadataSourceProvider);
    final basis = unit.matchAgainst;
    final query = releaseQueryFor(basis);
    final ranked = rankCandidates(
      await source.searchReleases(query),
      fileCount: basis.length,
      album: query.album,
      artist: query.artist,
    );
    if (ranked.isEmpty) return null;

    final fetched = await fetchRelease(source, ranked.first.id, fields);
    final detail = fetched.detail;
    final trackOf = {
      for (final MapEntry(:key, :value) in assignTracks(basis, detail).entries)
        key.file.path: value,
    };
    final assignment = <MusicEntry, ReleaseTrack?>{
      for (final song in unit.songs) song: trackOf[song.file.path],
    };
    final proposals = proposalsFor(
      assignment: assignment,
      release: detail,
      fields: fields,
      tags: tags,
      fallbackGenres: fetched.fallbackGenres,
      cover: fetched.cover,
    );

    return (
      confidence: recordConfidence(
        unit,
        query: query,
        release: detail,
        assignment: assignment,
        proposals: proposals,
      ),
      release: detail.release,
      proposals: proposals,
      coverUnavailable: fetched.coverUnavailable,
    );
  }

  /// The best recording for the lone track [unit], filed under the release
  /// its best appearance is on.
  Future<_Found?> _findTrack(
    BatchUnit unit,
    Set<AutofillField> fields,
    Map<String, FileTags> tags,
  ) async {
    final source = ref.read(metadataSourceProvider);
    final song = unit.songs.single;
    final query = recordingQueryFor(song);
    final matches = await source.searchRecordings(query);
    final best = rankAppearances(
      matches,
      title: query.title,
      artist: query.artist,
    ).firstOrNull;
    if (best == null) return null;

    final match = matches.firstWhere((m) => m.appearances.contains(best));
    final fetched = await fetchRelease(source, best.release.id, fields);
    final detail = fetched.detail;
    final byRecording = detail.tracks
        .where((t) => t.recordingId == match.recordingId)
        .firstOrNull;
    final assignment = byRecording != null
        ? <MusicEntry, ReleaseTrack?>{song: byRecording}
        : assignTracks([song], detail);
    final proposals = proposalsFor(
      assignment: assignment,
      release: detail,
      fields: fields,
      tags: tags,
      fallbackGenres: fetched.fallbackGenres,
      cover: fetched.cover,
    );

    // A recording found on no track of its release is not surely any of its
    // tracks: the one its number or title points at was never judged, and
    // nothing at all may be there to propose. It is shown, not written.
    final confidence = byRecording == null
        ? const Doubtful(DoubtReason.uncertainTrack)
        : trackConfidence(song, match: match, appearance: best);

    return (
      confidence: confidence,
      release: detail.release,
      proposals: proposals,
      coverUnavailable: fetched.coverUnavailable,
    );
  }

  /// Writes the accepted changes of [proposals], the playing file last; how
  /// each went by path, or `null` where the container went meanwhile.
  Future<Map<String, WriteOutcome>?> _write(
    List<FileProposal> proposals,
  ) async {
    final writer = ref.read(tagWriterProvider);
    final ordered = playingLast(
      proposals,
      ref.read(audioPlaybackControllerProvider).current?.path,
    );

    final writes = <String, WriteOutcome>{};
    for (final proposal in ordered) {
      final path = proposal.entry.file.path;
      writes[path] = await writer.write(path, {
        for (final change in proposal.changes)
          if (change.accepted) change.field: change.after,
      }, expected: proposal.entry.file);
      if (!ref.mounted) return null;
    }

    return writes;
  }

  Future<void> _rewrite(int generation) async {
    // This batch's outcomes, held on to: a batch started meanwhile replaces
    // the list, and none of its files are this retry's to write.
    final outcomes = _outcomes;
    _retrying = true;
    try {
      for (var i = 0; i < outcomes.length; i++) {
        final outcome = outcomes[i];
        if (outcome == null) continue;

        final again = [
          for (final proposal in outcome.proposals)
            if (proposal.acceptedCount > 0 &&
                _retryable(outcome.writes[proposal.entry.file.path]))
              proposal,
        ];
        if (again.isEmpty) continue;

        final writes = await _write(again);
        if (writes == null) return;
        if (writes.containsValue(WriteOutcome.written)) {
          _writtenSinceRescan = true;
        }
        // Another batch took this one's place, or it was cleared, while the
        // files were written: the rest is forgotten with it.
        if (generation != _generation) break;

        final merged = {...outcome.writes, ...writes};
        outcomes[i] = outcome.copyWith(
          kind: _writtenOrFailed(merged),
          proposals: _toRetry(outcome.proposals, merged),
          writes: merged,
        );
        state = state.copyWith(outcomes: _listed());
      }

      _rescanIfWritten();
    } finally {
      _retrying = false;
    }
  }

  static bool _retryable(WriteOutcome? outcome) =>
      outcome == WriteOutcome.inUse || outcome == WriteOutcome.failed;

  /// Notes that files were written, and asks for the rescan where the last
  /// ask was a minute ago or more.
  void _wrote() {
    _writtenSinceRescan = true;
    final last = _lastRescan;
    final now = ref.read(clockProvider)();
    if (last != null && now.difference(last) < _rescanEvery) return;

    _rescan(now);
  }

  void _rescanIfWritten() {
    if (_writtenSinceRescan && ref.mounted) _rescan(ref.read(clockProvider)());
  }

  void _rescan(DateTime now) {
    _lastRescan = now;
    _writtenSinceRescan = false;
    unawaited(ref.read(scanControllerProvider.notifier).rescanSoon());
  }

  List<UnitOutcome> _listed() => [for (final outcome in _outcomes) ?outcome];

  /// The tags of [path], or none writable where they cannot be read: such a
  /// file is left out of the writes rather than failing its record.
  Future<FileTags> _inspect(TagWriter writer, String path) async {
    try {
      return await writer.inspect(path);
    } on Object catch (error) {
      _log.info('the tags of a batch song could not be read', error);
      return FileTags.unwritable;
    }
  }

  Future<void> _remember(Set<AutofillField> fields) async {
    try {
      await ref
          .read(settingsStoreProvider)
          .setString(
            AutofillController.fieldsSettingsKey,
            AutofillField.encode(fields),
          );
    } on Object catch (error) {
      _log.fine('the autofill choice could not be saved', error);
    }
  }
}
