import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../application/autofill_controller.dart';
import '../domain/autofill_field.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';
import 'autofill_field_names.dart';

/// Where the owner sees every change an autofill would make, and confirms it.
class AutofillScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [entries].
  const AutofillScreen({required this.entries, required this.fields, required this.kind, super.key});

  /// The files to fill.
  final List<MusicEntry> entries;

  /// The tags the owner chose.
  final Set<AutofillField> fields;

  /// A record or a lone track.
  final AutofillKind kind;

  @override
  ConsumerState<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends ConsumerState<AutofillScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame, so the controller is being watched — kept alive —
    // before the lookup starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(autofillControllerProvider.notifier).start(widget.entries, widget.fields, kind: widget.kind),
      );
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(autofillControllerProvider);
    final controller = ref.read(autofillControllerProvider.notifier);

    ref.listen(autofillControllerProvider.select((s) => s.query), (_, query) {
      if (_query.text != query) _query.text = query;
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autofillAction)),
      body: switch (state.stage) {
        AutofillStage.idle || AutofillStage.searching => _Waiting(text: l10n.autofillSearching),
        AutofillStage.failed => _Failed(
          failure: state.failure,
          onRetry: () => unawaited(controller.retryLookup()),
        ),
        AutofillStage.writing => _Waiting(text: l10n.autofillWriting(state.written, state.total)),
        AutofillStage.finished => _Summary(state: state, onRetry: () => unawaited(controller.retry())),
        AutofillStage.reviewing => _Review(state: state, query: _query),
      },
      bottomNavigationBar: switch (state.stage) {
        AutofillStage.reviewing => _WriteBar(state: state),
        AutofillStage.writing => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton(onPressed: controller.cancel, child: Text(l10n.autofillCancel)),
        ),
        AutofillStage.finished => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillClose)),
        ),
        _ => null,
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(text),
      ],
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.failure, required this.onRetry});

  final MetadataSourceFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(failure == MetadataSourceFailure.rateLimited ? l10n.autofillRateLimited : l10n.autofillUnreachable),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(l10n.autofillTryAgain)),
        ],
      ),
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.state, required this.query});

  final AutofillState state;
  final TextEditingController query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(autofillControllerProvider.notifier);
    final release = state.release;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: query,
                decoration: InputDecoration(labelText: l10n.autofillSearchLabel),
                onSubmitted: (text) => unawaited(controller.search(text)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => unawaited(controller.search(query.text)),
              child: Text(l10n.autofillSearchAgain),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (release == null)
          Text(l10n.autofillNothingFound, style: theme.textTheme.titleMedium)
        else ...[
          _ReleaseHeader(release: release.release, candidates: state.candidates),
          if (state.refusal != null) _Refusal(decision: state.refusal!),
          if (state.coverMissing)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(l10n.autofillCoverMissing, style: theme.textTheme.bodySmall),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => controller.toggleAll(state.acceptedCount == 0),
              child: Text(state.acceptedCount == 0 ? l10n.autofillTickAll : l10n.autofillUntickAll),
            ),
          ),
          for (final proposal in state.proposals) _ProposalCard(proposal: proposal),
        ],
      ],
    );
  }
}

class _ReleaseHeader extends ConsumerWidget {
  const _ReleaseHeader({required this.release, required this.candidates});

  final ReleaseCandidate release;
  final List<ReleaseCandidate> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        title: Text(release.title, style: theme.textTheme.titleMedium),
        subtitle: Text(_describe(release)),
        trailing: candidates.length < 2
            ? null
            : MenuAnchor(
                menuChildren: [
                  for (final candidate in candidates)
                    MenuItemButton(
                      onPressed: () => unawaited(
                        ref.read(autofillControllerProvider.notifier).chooseRelease(candidate.id),
                      ),
                      child: Text('${candidate.title} — ${_describe(candidate)}'),
                    ),
                ],
                builder: (context, menu, _) => TextButton(
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  child: Text(l10n.autofillDifferentRelease),
                ),
              ),
      ),
    );
  }
}

/// A release's artist, year, country, format and disambiguation, as one line.
String _describe(ReleaseCandidate release) => [
  release.artist,
  if (release.year case final year?) '$year',
  ?release.country,
  ?release.format,
  ?release.disambiguation,
].where((part) => part.isNotEmpty).join(' · ');

class _Refusal extends ConsumerWidget {
  const _Refusal({required this.decision});

  final LibraryAccessDecision decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(l10n.autofillAccessRefused, style: TextStyle(color: theme.colorScheme.error))),
          if (decision == LibraryAccessDecision.deniedPermanently)
            TextButton(
              onPressed: () => unawaited(ref.read(libraryAccessControllerProvider.notifier).openSettings()),
              child: Text(l10n.autofillOpenSettings),
            ),
        ],
      ),
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal});

  final FileProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(autofillControllerProvider.notifier);
    final path = proposal.entry.file.path;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final note = switch (proposal.blockedBecause) {
      ProposalBlock.unwritableFormat => l10n.autofillUnwritable,
      ProposalBlock.noMatch => l10n.autofillNoMatch,
      null when proposal.changes.isEmpty => l10n.autofillNoChanges,
      null => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(proposal.entry.file.name, style: theme.textTheme.titleSmall),
            if (note != null) Text(note, style: muted),
            if (proposal.notWritable.isNotEmpty)
              Text(
                l10n.autofillNotWritableFields(
                  [for (final f in proposal.notWritable) autofillFieldName(l10n, f)].join(', '),
                ),
                style: muted,
              ),
            for (final change in proposal.changes)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: change.accepted,
                onChanged: (_) => controller.toggle(path, change.field),
                title: Text(autofillFieldName(l10n, change.field)),
                subtitle: change.field == AutofillField.cover
                    ? _CoverChange(before: change.before as Uint8List?, after: change.after as Uint8List?)
                    : Row(
                        children: [
                          Flexible(child: Text(_shown(change.before), style: muted)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                            child: Icon(Icons.arrow_forward, size: 14),
                          ),
                          Flexible(child: Text(_shown(change.after))),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  static String _shown(Object? value) => value == null ? '—' : '$value';
}

class _CoverChange extends StatelessWidget {
  const _CoverChange({required this.before, required this.after});

  final Uint8List? before;
  final Uint8List? after;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _thumb(before),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Icon(Icons.arrow_forward, size: 14),
      ),
      _thumb(after),
    ],
  );

  Widget _thumb(Uint8List? bytes) => SizedBox.square(
    dimension: 48,
    child: bytes == null
        ? const Icon(Icons.album_outlined)
        : Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
  );
}

class _WriteBar extends ConsumerWidget {
  const _WriteBar({required this.state});

  final AutofillState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          onPressed: state.acceptedCount == 0
              ? null
              : () => unawaited(ref.read(autofillControllerProvider.notifier).write()),
          child: Text(l10n.autofillWrite(state.acceptedCount, state.filesWithChanges)),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.onRetry});

  final AutofillState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final written = state.outcomes.values.where((o) => o == WriteOutcome.written).length;
    final refused = {
      for (final MapEntry(:key, :value) in state.outcomes.entries)
        if (value != WriteOutcome.written) key: value,
    };
    // Files that had ticked changes but were never reached: cancelled first.
    final unreached = [
      for (final p in state.proposals)
        if (p.acceptedCount > 0 && !state.outcomes.containsKey(p.entry.file.path)) p.entry.file.path,
    ];
    final retryable = refused.values.any((o) => o == WriteOutcome.inUse || o == WriteOutcome.failed);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.autofillWritten(written), style: theme.textTheme.titleMedium),
        for (final MapEntry(key: path, value: outcome) in refused.entries)
          ListTile(
            dense: true,
            title: Text(path.split(RegExp(r'[/\\]')).last),
            subtitle: Text(switch (outcome) {
              WriteOutcome.changedSinceRead => l10n.autofillOutcomeChanged,
              WriteOutcome.inUse => l10n.autofillOutcomeInUse,
              WriteOutcome.denied => l10n.autofillOutcomeDenied,
              WriteOutcome.unsupported => l10n.autofillOutcomeUnsupported,
              _ => l10n.autofillOutcomeFailed,
            }),
          ),
        for (final path in unreached)
          ListTile(
            dense: true,
            title: Text(path.split(RegExp(r'[/\\]')).last),
            subtitle: Text(l10n.autofillOutcomeNotWritten),
          ),
        if (retryable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRetry, child: Text(l10n.autofillTryAgain)),
          ),
      ],
    );
  }
}
