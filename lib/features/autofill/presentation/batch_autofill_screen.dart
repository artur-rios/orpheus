import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/music_entry.dart';
import '../../shell/presentation/confirmation_dialog.dart';
import '../application/autofill_controller.dart';
import '../application/batch_autofill_controller.dart';
import '../domain/batch_plan.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';
import 'autofill_screen.dart';
import 'doubt_reason_names.dart';

/// Where a batch autofill is followed: its progress while it runs, and once
/// it is done its summary and the records kept for the owner to check.
///
/// The batch outlives the screen: closing it leaves the batch running, and
/// opening it again shows where it has got to.
class BatchAutofillScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BatchAutofillScreen({super.key});

  /// Opens the screen over the current route.
  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const BatchAutofillScreen()));

  @override
  ConsumerState<BatchAutofillScreen> createState() =>
      _BatchAutofillScreenState();
}

class _BatchAutofillScreenState extends ConsumerState<BatchAutofillScreen> {
  @override
  void initState() {
    super.initState();
    final controller = ref.read(batchAutofillControllerProvider.notifier);
    ref.listenManual(batchAutofillControllerProvider.select((s) => s.stage), (
      _,
      stage,
    ) {
      switch (stage) {
        // It ended while the owner watched: there is no summary to come back
        // to.
        case BatchStage.finished:
          unawaited(Future.microtask(controller.markSeen));
        // The list was cleared: nothing is left to show.
        case BatchStage.idle:
          unawaited(Navigator.of(context).maybePop());
        case BatchStage.running || BatchStage.paused:
          break;
      }
    });
    // Opened on a batch already finished: this is the summary being seen.
    // After the first frame, so no provider is changed while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(batchAutofillControllerProvider);
    final controller = ref.read(batchAutofillControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autofillBatchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (state.refusal case final refusal?)
            AutofillRefusal(decision: refusal),
          ...switch (state.stage) {
            BatchStage.idle => const <Widget>[],
            BatchStage.running ||
            BatchStage.paused => [_Progress(state: state)],
            BatchStage.finished => [
              _Summary(
                state: state,
                onReview: (outcome) => _review(state, outcome),
                onRetry: () => unawaited(controller.retryFailed()),
                onClear: () => unawaited(_clear()),
              ),
            ],
          },
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: switch (state.stage) {
            BatchStage.running => Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.stop,
                    child: Text(l10n.autofillBatchStop),
                  ),
                ),
                Expanded(child: _close(context)),
              ],
            ),
            BatchStage.paused => Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.stop,
                    child: Text(l10n.autofillBatchStop),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => unawaited(controller.resume()),
                    child: Text(l10n.autofillTryAgain),
                  ),
                ),
              ],
            ),
            BatchStage.idle || BatchStage.finished => _close(context),
          },
        ),
      ),
    );
  }

  Widget _close(BuildContext context) => FilledButton(
    onPressed: () => Navigator.pop(context),
    child: Text(AppLocalizations.of(context).autofillClose),
  );

  /// Opens the review of [outcome]'s songs, and marks it reviewed if the
  /// owner writes anything there.
  void _review(BatchAutofillState state, UnitOutcome outcome) {
    final controller = ref.read(batchAutofillControllerProvider.notifier);
    final unit = outcome.unit;

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AutofillScreen(
            entries: unit.songs,
            matchAgainst: unit.matchAgainst,
            fields: state.fields,
            kind: unit.kind == BatchUnitKind.record
                ? AutofillKind.record
                : AutofillKind.track,
            onWritten: () => controller.markReviewed(unit),
          ),
        ),
      ),
    );
  }

  /// Forgets the records kept for the owner, once they have said so.
  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(batchAutofillControllerProvider.notifier);

    final sure = await ConfirmationDialog.ask(
      context,
      title: l10n.autofillBatchClearTitle,
      body: l10n.autofillBatchClearBody,
      confirmLabel: l10n.autofillBatchClearConfirm,
    );
    if (sure) controller.clear();
  }
}

/// How far a batch has got, and what it has found so far.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final BatchAutofillState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = state.plan?.units.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.autofillBatchProgress(state.done, total),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(value: total == 0 ? 0 : state.done / total),
        const SizedBox(height: AppSpacing.md),
        _Counts(state: state),
        if (state.stage == BatchStage.paused) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.autofillBatchPaused,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// The batch's live counts.
class _Counts extends StatelessWidget {
  const _Counts({required this.state});

  final BatchAutofillState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        Text(l10n.autofillBatchUpdated(state.updated)),
        Text(l10n.autofillBatchNeedYou(state.needYou)),
        Text(l10n.autofillBatchAlreadyRight(state.alreadyRight)),
        Text(l10n.autofillBatchNotFound(state.notFound)),
        Text(l10n.autofillBatchSkipped(state.skipped)),
      ],
    );
  }
}

/// A finished batch: the headline, then what became of each record that was
/// not simply written.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.onReview,
    required this.onRetry,
    required this.onClear,
  });

  final BatchAutofillState state;

  /// Called with the doubtful record the owner tapped.
  final void Function(UnitOutcome outcome) onReview;

  /// Called when the owner asks to write again the files that were in use or
  /// failed.
  final VoidCallback onRetry;

  /// Called when the owner asks to forget the records waiting for them.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    List<UnitOutcome> of(UnitOutcomeKind kind) => [
      for (final outcome in state.outcomes)
        if (outcome.kind == kind) outcome,
    ];
    final needYou = of(UnitOutcomeKind.doubtful);
    final notFound = of(UnitOutcomeKind.notFound);
    final notLookedUp = of(UnitOutcomeKind.notLookedUp);
    final problems = [
      for (final outcome in state.outcomes)
        if (_hasProblem(outcome)) outcome,
    ];
    final retryable = state.outcomes.any(
      (outcome) => outcome.writes.values.any(
        (write) => write == WriteOutcome.inUse || write == WriteOutcome.failed,
      ),
    );
    final cantChange = state.notWritableSongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.autofillBatchSummary(state.updated, state.needYou),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Counts(state: state),
        if (retryable || state.needYou > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (retryable)
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: Text(l10n.autofillTryAgain),
                  ),
                if (state.needYou > 0)
                  TextButton(
                    onPressed: onClear,
                    child: Text(l10n.autofillBatchClearList),
                  ),
              ],
            ),
          ),
        if (needYou.isNotEmpty)
          _Section(
            title: l10n.autofillBatchSectionNeedYou,
            children: [
              for (final outcome in needYou)
                _NeedYouRow(outcome: outcome, onTap: () => onReview(outcome)),
            ],
          ),
        if (notFound.isNotEmpty)
          _Section(
            title: l10n.autofillBatchSectionNotFound,
            children: [for (final outcome in notFound) _UnitRow(outcome)],
          ),
        if (cantChange.isNotEmpty)
          _Section(
            title: l10n.autofillBatchSectionNotWritable,
            children: [for (final song in cantChange) _SongRow(song)],
          ),
        if (problems.isNotEmpty)
          _Section(
            title: l10n.autofillBatchSectionFailed,
            children: [for (final outcome in problems) _ProblemRow(outcome)],
          ),
        if (notLookedUp.isNotEmpty)
          _Section(
            title: l10n.autofillBatchSectionNotLookedUp,
            children: [for (final outcome in notLookedUp) _UnitRow(outcome)],
          ),
      ],
    );
  }

  /// Whether [outcome] went wrong in a way the owner should hear of: it could
  /// not be looked up or written, some of its files were refused, or its cover
  /// could not be downloaded though everything else was done.
  static bool _hasProblem(UnitOutcome outcome) => switch (outcome.kind) {
    UnitOutcomeKind.failed || UnitOutcomeKind.unreachable => true,
    UnitOutcomeKind.updated || UnitOutcomeKind.alreadyRight =>
      outcome.coverUnavailable || _refused(outcome).isNotEmpty,
    _ => false,
  };
}

/// The files of [outcome] a write was refused, and how.
Map<String, WriteOutcome> _refused(UnitOutcome outcome) => {
  for (final MapEntry(:key, :value) in outcome.writes.entries)
    if (value != WriteOutcome.written) key: value,
};

/// A heading and the rows under it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xs,
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      ...children,
    ],
  );
}

/// A doubtful record: what it is, what was proposed for it, and why it was not
/// written.
class _NeedYouRow extends StatelessWidget {
  const _NeedYouRow({required this.outcome, required this.onTap});

  final UnitOutcome outcome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final artist = _artistOf(outcome.unit);
    final release = outcome.release;
    final doubt = outcome.doubt;

    return ListTile(
      onTap: onTap,
      title: Text(_titleOf(outcome.unit)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artist != null) Text(artist),
          if (release != null)
            Row(
              children: [
                const Icon(Icons.arrow_forward, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(_describe(release))),
              ],
            ),
          if (doubt != null) Text(doubtReasonName(doubt, l10n), style: muted),
          if (outcome.coverUnavailable)
            Text(l10n.autofillCoverUnavailable, style: muted),
        ],
      ),
      trailing: outcome.reviewed
          ? Icon(Icons.check_circle_outline, color: theme.colorScheme.primary)
          : const Icon(Icons.chevron_right),
    );
  }
}

/// A record or lone track that is only named.
class _UnitRow extends StatelessWidget {
  const _UnitRow(this.outcome);

  final UnitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final artist = _artistOf(outcome.unit);

    return ListTile(
      dense: true,
      title: Text(_titleOf(outcome.unit)),
      subtitle: artist == null ? null : Text(artist),
    );
  }
}

/// A song no tag could be written to, and why.
class _SongRow extends StatelessWidget {
  const _SongRow(this.song);

  final MusicEntry song;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      dense: true,
      title: Text(song.file.name),
      subtitle: Text(
        canWriteTagsTo(song.file.path)
            ? l10n.autofillUnsafeTags
            : l10n.autofillUnwritable,
      ),
    );
  }
}

/// A record that could not be looked up or whose files could not all be
/// written, with each refused file and why.
class _ProblemRow extends StatelessWidget {
  const _ProblemRow(this.outcome);

  final UnitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final artist = _artistOf(outcome.unit);

    return ListTile(
      dense: true,
      title: Text(_titleOf(outcome.unit)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artist != null) Text(artist),
          if (outcome.kind == UnitOutcomeKind.unreachable)
            Text(l10n.autofillUnreachable, style: muted),
          for (final MapEntry(key: path, value: write) in _refused(
            outcome,
          ).entries) ...[
            Text(p.basename(path)),
            Text(writeOutcomeReason(l10n, path, write), style: muted),
          ],
          if (outcome.coverUnavailable)
            Text(l10n.autofillCoverUnavailable, style: muted),
        ],
      ),
    );
  }
}

/// What a record is called: its album, or its folder where its songs name no
/// album, or a lone track's title.
String _titleOf(BatchUnit unit) {
  final first = unit.songs.first;
  if (unit.kind == BatchUnitKind.track) return first.title ?? first.file.name;

  return first.album ?? p.basename(first.file.directory);
}

/// Who a record is by, where its songs say.
String? _artistOf(BatchUnit unit) {
  final first = unit.songs.first;

  return unit.kind == BatchUnitKind.track ? first.artist : first.albumArtist;
}

/// A release's title, artist and year, as one line.
String _describe(ReleaseCandidate release) => [
  release.title,
  release.artist,
  if (release.year case final year?) '$year',
].where((part) => part.isNotEmpty).join(' · ');
