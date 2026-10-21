import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../domain/autofill_field.dart';
import '../domain/matching.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';
import 'release_fetch.dart';

/// Where an autofill is.
enum AutofillStage {
  /// Not started.
  idle,

  /// Looking the record up.
  searching,

  /// Showing the owner what would change.
  reviewing,

  /// Writing what they confirmed.
  writing,

  /// Done; [AutofillState.outcomes] says how each file went.
  finished,

  /// The lookup could not run; [AutofillState.failure] says why.
  failed,
}

/// What an autofill was started on.
enum AutofillKind {
  /// A record, matched as a release.
  record,

  /// A lone track, matched as a recording.
  track,
}

/// One autofill session.
class AutofillState {
  /// Creates a state.
  const AutofillState({
    this.stage = AutofillStage.idle,
    this.kind = AutofillKind.record,
    this.fields = const {},
    this.query = '',
    this.candidates = const [],
    this.release,
    this.proposals = const [],
    this.written = 0,
    this.total = 0,
    this.outcomes = const {},
    this.failure,
    this.refusal,
    this.coverMissing = false,
    this.coverUnavailable = false,
  });

  /// Where it is.
  final AutofillStage stage;

  /// What it was started on.
  final AutofillKind kind;

  /// The tags the owner chose.
  final Set<AutofillField> fields;

  /// The search as the owner can see and edit it.
  final String query;

  /// Every release on offer, best first.
  final List<ReleaseCandidate> candidates;

  /// The release proposed from, or `null` where nothing was found.
  final ReleaseDetail? release;

  /// What would change, file by file.
  final List<FileProposal> proposals;

  /// How many files have been written so far.
  final int written;

  /// How many are being written.
  final int total;

  /// How each written file went, by path.
  final Map<String, WriteOutcome> outcomes;

  /// Why the lookup failed, where it did.
  final MetadataSourceFailure? failure;

  /// Why nothing was written, where the owner refused access.
  final LibraryAccessDecision? refusal;

  /// Whether the cover was chosen and the release had none to give.
  final bool coverMissing;

  /// Whether the cover was chosen and could not be downloaded: the release
  /// may well have one.
  final bool coverUnavailable;

  /// How many changes are ticked.
  int get acceptedCount =>
      proposals.fold(0, (sum, proposal) => sum + proposal.acceptedCount);

  /// How many files have a ticked change.
  int get filesWithChanges =>
      proposals.where((proposal) => proposal.acceptedCount > 0).length;

  /// A copy with the given changes. [failure] and [refusal] clear unless
  /// passed: each describes one moment.
  AutofillState copyWith({
    AutofillStage? stage,
    AutofillKind? kind,
    Set<AutofillField>? fields,
    String? query,
    List<ReleaseCandidate>? candidates,
    ReleaseDetail? release,
    bool clearRelease = false,
    List<FileProposal>? proposals,
    int? written,
    int? total,
    Map<String, WriteOutcome>? outcomes,
    MetadataSourceFailure? failure,
    LibraryAccessDecision? refusal,
    bool? coverMissing,
    bool? coverUnavailable,
  }) => AutofillState(
    stage: stage ?? this.stage,
    kind: kind ?? this.kind,
    fields: fields ?? this.fields,
    query: query ?? this.query,
    candidates: candidates ?? this.candidates,
    release: clearRelease ? null : release ?? this.release,
    proposals: proposals ?? this.proposals,
    written: written ?? this.written,
    total: total ?? this.total,
    outcomes: outcomes ?? this.outcomes,
    failure: failure,
    refusal: refusal,
    coverMissing: coverMissing ?? this.coverMissing,
    coverUnavailable: coverUnavailable ?? this.coverUnavailable,
  );
}

/// Looks a record or a track up, proposes its tags, and writes the ones the
/// owner confirms.
///
/// Auto-disposed: it lives exactly as long as the review screen watching it.
/// Every await is followed by a check that it still does, because the owner
/// can close the screen while MusicBrainz is still answering.
///
/// Writing is the exception: a closed screen finishes the writes the owner
/// confirmed and still asks for the rescan, and only [cancel] stops them.
class AutofillController extends Notifier<AutofillState> {
  static final Logger _log = Logger('autofill');

  /// The settings key the last choice of tags is kept under.
  static const String fieldsSettingsKey = 'autofillFields';

  List<MusicEntry> _entries = const [];
  List<MusicEntry>? _matchAgainst;
  Map<String, FileTags> _tags = const {};
  String? _recordingId;
  bool _cancelled = false;
  bool _writing = false;
  String? _lastText;

  @override
  AutofillState build() => const AutofillState();

  /// The tags the owner chose last time, or the defaults.
  Set<AutofillField> rememberedFields() => AutofillField.decode(
    ref.read(settingsStoreProvider).getString(fieldsSettingsKey),
  );

  /// Starts an autofill of [entries] for [fields].
  ///
  /// With [matchAgainst], [entries] are some files of a bigger record: the
  /// record is looked up, ranked and its tracks assigned as for the whole of
  /// [matchAgainst], and only [entries] are proposed changes.
  Future<void> start(
    List<MusicEntry> entries,
    Set<AutofillField> fields, {
    required AutofillKind kind,
    List<MusicEntry>? matchAgainst,
  }) async {
    _entries = entries;
    _matchAgainst = matchAgainst;
    unawaited(_remember(fields));

    final basis = matchAgainst ?? entries;
    final text = kind == AutofillKind.record
        ? _join(releaseQueryFor(basis).album, releaseQueryFor(basis).artist)
        : _join(
            recordingQueryFor(entries.single).title,
            recordingQueryFor(entries.single).artist,
          );

    state = AutofillState(
      stage: AutofillStage.searching,
      kind: kind,
      fields: fields,
      query: text,
    );

    final writer = ref.read(tagWriterProvider);
    final tags = <String, FileTags>{};
    for (final entry in entries) {
      tags[entry.file.path] = await writer.inspect(entry.file.path);
      if (!ref.mounted) return;
    }
    _tags = tags;

    _lastText = null;
    await _lookUp(null);
  }

  /// Searches again with the owner's own [text].
  Future<void> search(String text) async {
    state = state.copyWith(stage: AutofillStage.searching, query: text);
    _lastText = text.trim().isEmpty ? null : text.trim();
    await _lookUp(_lastText);
  }

  /// Runs the lookup that failed again, with the words it had, and leaves the
  /// owner's search text as it is.
  Future<void> retryLookup() async {
    state = state.copyWith(stage: AutofillStage.searching);
    await _lookUp(_lastText);
  }

  /// Proposes from the candidate [id] instead.
  Future<void> chooseRelease(String id) async {
    state = state.copyWith(stage: AutofillStage.searching);
    await _propose(id);
  }

  /// Ticks or unticks one change.
  void toggle(String path, AutofillField field) => _edit(
    (proposal) => proposal.entry.file.path != path
        ? proposal
        : proposal.withChanges([
            for (final change in proposal.changes)
              change.field == field
                  ? change.withAccepted(!change.accepted)
                  : change,
          ]),
  );

  /// Ticks or unticks every change of one file.
  void toggleFile(String path, bool accepted) => _edit(
    (proposal) => proposal.entry.file.path != path
        ? proposal
        : proposal.withChanges([
            for (final c in proposal.changes) c.withAccepted(accepted),
          ]),
  );

  /// Ticks or unticks every change.
  void toggleAll(bool accepted) => _edit(
    (proposal) => proposal.withChanges([
      for (final c in proposal.changes) c.withAccepted(accepted),
    ]),
  );

  /// Writes every ticked change, then rescans.
  Future<void> write() => _writeFiles([
    for (final p in state.proposals)
      if (p.acceptedCount > 0) p,
  ]);

  /// Writes again the files that were in use or failed.
  Future<void> retry() => _writeFiles([
    for (final p in state.proposals)
      if (p.acceptedCount > 0 &&
          (state.outcomes[p.entry.file.path] == WriteOutcome.inUse ||
              state.outcomes[p.entry.file.path] == WriteOutcome.failed))
        p,
  ], keep: state.outcomes);

  /// Stops after the file being written.
  void cancel() => _cancelled = true;

  Future<void> _lookUp(String? text) async {
    final source = ref.read(metadataSourceProvider);

    try {
      if (state.kind == AutofillKind.record) {
        final basis = _matchAgainst ?? _entries;
        final query = releaseQueryFor(basis);
        final found = await source.searchReleases(
          text == null ? query : ReleaseQuery(text: text),
        );
        if (!ref.mounted) return;

        final ranked = rankCandidates(
          found,
          fileCount: basis.length,
          album: query.album,
          artist: query.artist,
        );
        state = state.copyWith(candidates: ranked);
        if (ranked.isEmpty) {
          state = state.copyWith(
            stage: AutofillStage.reviewing,
            clearRelease: true,
            proposals: const [],
          );
          return;
        }

        await _propose(ranked.first.id);
      } else {
        final query = recordingQueryFor(_entries.single);
        final found = await source.searchRecordings(
          text == null ? query : RecordingQuery(text: text),
        );
        if (!ref.mounted) return;

        final appearances = rankAppearances(
          found,
          title: query.title,
          artist: query.artist,
        );
        _recordingId = found.firstOrNull?.recordingId;
        final ranked = [for (final a in appearances) a.release];
        state = state.copyWith(candidates: ranked);
        if (ranked.isEmpty) {
          state = state.copyWith(
            stage: AutofillStage.reviewing,
            clearRelease: true,
            proposals: const [],
          );
          return;
        }

        await _propose(ranked.first.id);
      }
    } on MetadataSourceException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: AutofillStage.failed, failure: error.kind);
    }
  }

  Future<void> _propose(String releaseId) async {
    final source = ref.read(metadataSourceProvider);

    try {
      final fetched = await fetchRelease(source, releaseId, state.fields);
      if (!ref.mounted) return;

      final detail = fetched.detail;
      final assignment = switch (state.kind) {
        AutofillKind.track => _assignLoneTrack(detail),
        AutofillKind.record => _assignRecord(detail),
      };

      state = state.copyWith(
        stage: AutofillStage.reviewing,
        release: detail,
        coverMissing:
            state.fields.contains(AutofillField.cover) &&
            fetched.cover == null &&
            !fetched.coverUnavailable,
        coverUnavailable: fetched.coverUnavailable,
        proposals: proposalsFor(
          assignment: assignment,
          release: detail,
          fields: state.fields,
          tags: _tags,
          fallbackGenres: fetched.fallbackGenres,
          cover: fetched.cover,
        ),
      );
    } on MetadataSourceException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: AutofillStage.failed, failure: error.kind);
    }
  }

  /// Each of [_entries]' place on [detail]: assigned among the whole of
  /// [_matchAgainst] where there is one, so a file is not given a track that
  /// another file of the record has the better claim to.
  Map<MusicEntry, ReleaseTrack?> _assignRecord(ReleaseDetail detail) {
    final all = _matchAgainst;
    if (all == null) return assignTracks(_entries, detail);

    final wanted = {for (final entry in _entries) entry.file.path};
    return {
      for (final MapEntry(:key, :value) in assignTracks(all, detail).entries)
        if (wanted.contains(key.file.path)) key: value,
    };
  }

  /// The lone track's place on [detail]: the recording it was matched as,
  /// else whatever the record-wide rules find.
  Map<MusicEntry, ReleaseTrack?> _assignLoneTrack(ReleaseDetail detail) {
    final entry = _entries.single;
    final byRecording = detail.tracks
        .where((t) => t.recordingId != null && t.recordingId == _recordingId)
        .firstOrNull;

    return byRecording != null
        ? {entry: byRecording}
        : assignTracks(_entries, detail);
  }

  Future<void> _writeFiles(
    List<FileProposal> chosen, {
    Map<String, WriteOutcome> keep = const {},
  }) async {
    // One write at a time: a second tap while the access prompt is up, or
    // while files are going out, would write every file twice.
    if (chosen.isEmpty || _writing) return;

    _writing = true;
    try {
      await _writeChosen(chosen, keep);
    } finally {
      _writing = false;
    }
  }

  Future<void> _writeChosen(
    List<FileProposal> chosen,
    Map<String, WriteOutcome> keep,
  ) async {
    final access = await ref
        .read(libraryAccessControllerProvider.notifier)
        .ensureWritable();
    if (!ref.mounted) return;
    if (!access.isGranted) {
      state = state.copyWith(stage: AutofillStage.reviewing, refusal: access);
      return;
    }

    final ordered = playingLast(
      chosen,
      ref.read(audioPlaybackControllerProvider).current?.path,
    );

    _cancelled = false;
    final outcomes = {...keep};
    state = state.copyWith(
      stage: AutofillStage.writing,
      written: 0,
      total: ordered.length,
      outcomes: outcomes,
    );

    // Both resolved now: once the screen closes `ref` can no longer be read,
    // and the writes the owner confirmed are still to be finished and
    // followed by a rescan.
    final writer = ref.read(tagWriterProvider);
    final scan = ref.read(scanControllerProvider.notifier);
    var done = 0;
    var any = false;
    for (final proposal in ordered) {
      if (_cancelled) break;

      final path = proposal.entry.file.path;
      final outcome = await writer.write(path, {
        for (final c in proposal.changes)
          if (c.accepted) c.field: c.after,
      }, expected: proposal.entry.file);
      outcomes[path] = outcome;
      any = any || outcome == WriteOutcome.written;
      done++;
      if (ref.mounted) {
        state = state.copyWith(written: done, outcomes: {...outcomes});
      }
    }

    if (any) unawaited(scan.rescanSoon());
    if (!ref.mounted) return;

    state = state.copyWith(
      stage: AutofillStage.finished,
      outcomes: {...outcomes},
    );
  }

  void _edit(FileProposal Function(FileProposal proposal) edit) {
    state = state.copyWith(
      proposals: [for (final p in state.proposals) edit(p)],
    );
  }

  Future<void> _remember(Set<AutofillField> fields) async {
    try {
      await ref
          .read(settingsStoreProvider)
          .setString(fieldsSettingsKey, AutofillField.encode(fields));
    } on Object catch (error) {
      _log.fine('the autofill choice could not be saved', error);
    }
  }

  static String _join(String? a, String? b) =>
      [?a, ?b].where((s) => s.trim().isNotEmpty).join(' ');
}
