import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../autofill/domain/tag_writer.dart';
import '../../library/domain/library_access.dart';

/// What the tag editors say about a write that did not land, one track's or
/// several's alike.
///
/// Every outcome named: a new one is a compile error here rather than a
/// message the two forms pick differently.
String writeOutcomeMessage(AppLocalizations l10n, WriteOutcome outcome) =>
    switch (outcome) {
      WriteOutcome.changedSinceRead => l10n.autofillOutcomeChanged,
      WriteOutcome.inUse => l10n.autofillOutcomeInUse,
      WriteOutcome.denied => l10n.autofillOutcomeDenied,
      // A kind of file Orpheus writes, whose tag the editor refused.
      WriteOutcome.unsupported => l10n.autofillUnsafeTags,
      WriteOutcome.failed => l10n.autofillOutcomeFailed,
      // Never shown: a written file is no failure. Named so the switch stays
      // exhaustive.
      WriteOutcome.written => l10n.autofillOutcomeFailed,
    };

/// Why a save on a tag editor wrote nothing: the owner refused Orpheus write
/// access. Where the refusal is for good, the way to the system settings that
/// can undo it.
class TagEditAccessRefusal extends ConsumerWidget {
  /// Creates it for [refusal].
  const TagEditAccessRefusal({required this.refusal, super.key});

  /// What the owner answered.
  final LibraryAccessDecision refusal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.autofillAccessRefused,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
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
    );
  }
}
