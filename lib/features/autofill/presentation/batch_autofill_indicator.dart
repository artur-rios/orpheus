import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/breakpoints.dart';
import '../application/batch_autofill_controller.dart';
import 'batch_autofill_screen.dart';

/// The shell's way back to a batch autofill: its progress while it runs, and
/// once it is done how many records still need the owner.
///
/// Nothing at all unless [BatchAutofillState.showsIndicator]. The bar of a
/// phone or a compact window has no room for a sentence beside the search
/// field, so there it is the autofill icon with the figure on a badge and the
/// sentence as its tooltip. A tap opens the batch screen.
class BatchAutofillIndicator extends ConsumerWidget {
  /// Creates the indicator.
  const BatchAutofillIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(batchAutofillControllerProvider);
    if (!state.showsIndicator) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final text = switch (state.stage) {
      BatchStage.running => l10n.autofillBatchIndicatorRunning(
        state.done,
        state.plan?.units.length ?? 0,
      ),
      BatchStage.paused => l10n.autofillBatchIndicatorPaused,
      BatchStage.finished when state.needYou > 0 =>
        l10n.autofillBatchIndicatorNeedYou(state.needYou),
      BatchStage.finished => l10n.autofillBatchIndicatorDone,
      // Never shown: there is no batch to follow.
      BatchStage.idle => '',
    };
    // What the badge says: the progress, or who is waiting. Paused and done
    // say it in the sentence alone.
    final figure = switch (state.stage) {
      BatchStage.running => '${state.done}/${state.plan?.units.length ?? 0}',
      BatchStage.finished when state.needYou > 0 => '${state.needYou}',
      _ => null,
    };
    void open() => unawaited(BatchAutofillScreen.show(context));

    // The sentence needs the width the search field and the buttons leave:
    // below the medium tier it overflows the bar, so the icon speaks for it.
    if (Breakpoint.from(context) case Breakpoint.phone || Breakpoint.compact) {
      return IconButton(
        tooltip: text,
        icon: Badge(
          label: figure == null ? null : Text(figure),
          isLabelVisible: figure != null,
          child: const Icon(Icons.auto_fix_high_outlined),
        ),
        onPressed: open,
      );
    }

    return TextButton.icon(
      icon: const Icon(Icons.auto_fix_high_outlined),
      label: Text(text),
      onPressed: open,
    );
  }
}
