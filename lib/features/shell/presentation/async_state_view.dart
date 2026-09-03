import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/failures/failure.dart';
import '../../../core/failures/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

/// The shell's loading, failure, and loaded states, in one place.
///
/// Every perceptible operation in the application renders through this rather
/// than each screen growing its own spinner and its own error text.
///
/// The case worth naming: when the operation fails while the loading state is
/// showing, the spinner is *replaced* by the message and a retry. It is never
/// left spinning, and it is never dismissed into an unchanged screen with
/// nothing said.
class AsyncStateView<T> extends StatelessWidget {
  /// Creates a view over [value].
  const AsyncStateView({
    required this.value,
    required this.onRetry,
    required this.builder,
    this.emptyBuilder,
    this.isEmpty,
    super.key,
  });

  /// The operation being presented.
  final AsyncValue<T> value;

  /// Runs the operation again, from the failure state.
  final VoidCallback onRetry;

  /// Builds the loaded state.
  final Widget Function(BuildContext context, T data) builder;

  /// Builds the empty state, when the screen has one.
  ///
  /// Kept separate from [builder] so the empty state is a distinct thing on
  /// screen rather than an empty list.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Whether [T] counts as empty. Required alongside [emptyBuilder].
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) => switch (value) {
    // An error that is not a [Failure] has no family to name, so none is
    // invented for it: it falls through to the unexpected-failure message,
    // which is what an error the application does not know reads as anyway.
    AsyncError(:final error) => ShellFailureView(
      failure: error is Failure ? error : null,
      onRetry: onRetry,
    ),
    // Checked after the error so a refresh that fails reports the failure
    // rather than sitting on a spinner: AsyncValue keeps `isLoading` true
    // while it re-runs, and the loading state gives way.
    AsyncLoading() => const ShellLoadingView(),
    AsyncData(:final value) =>
      emptyBuilder != null && (isEmpty?.call(value) ?? false)
          ? emptyBuilder!(context)
          : builder(context, value),
  };
}

/// The loading state every operation shows while it runs.
class ShellLoadingView extends StatelessWidget {
  /// Creates the loading state.
  const ShellLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: AppLocalizations.of(context).loading,
      child: const CircularProgressIndicator(),
    ),
  );
}

/// The failure state, with a retry.
class ShellFailureView extends StatelessWidget {
  /// Creates the failure state for [failure].
  const ShellFailureView({required this.onRetry, this.failure, super.key});

  /// What went wrong, when it was a typed failure.
  ///
  /// `null` when the operation threw something outside the failure model — a
  /// bug rather than a condition — which reads as the unexpected-failure
  /// message. Either way the owner gets a sentence and a retry, never a stack
  /// trace.
  final Failure? failure;

  /// Runs the operation again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: AppSpacing.xl,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                failure?.localizedMessage(l10n) ?? l10n.failureUnexpected,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Autofocused: on a failure state the retry *is* the screen's
              // primary action, and it has to be reachable without a pointer.
              FilledButton.icon(
                autofocus: true,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
