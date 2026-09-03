import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

/// The preferences.
///
/// A dialog rather than a destination, because it is a handful of switches an
/// owner touches twice a year: a fourth entry in the navigation panel for it
/// would put it in front of them every session in exchange for nothing.
class PreferencesDialog extends ConsumerWidget {
  /// Creates the dialog.
  const PreferencesDialog({super.key});

  /// Opens it over [context].
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => const PreferencesDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Heading(text: l10n.settingsAppearance),
              DropdownButtonFormField<ThemeMode>(
                initialValue: preferences.themeMode,
                decoration: InputDecoration(labelText: l10n.settingsTheme),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(l10n.themeSystem),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(l10n.themeLight),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(l10n.themeDark),
                  ),
                ],
                onChanged: (mode) => mode == null
                    ? null
                    : unawaited(controller.setThemeMode(mode)),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                // The system choice is a `null` locale, and a dropdown cannot
                // hold `null` as a distinct value alongside real ones — so the
                // languages are keyed by their tag and the empty string is
                // "follow the system".
                initialValue: preferences.locale?.toLanguageTag() ?? '',
                decoration: InputDecoration(labelText: l10n.settingsLanguage),
                items: [
                  DropdownMenuItem(value: '', child: Text(l10n.languageSystem)),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(l10n.languageEnglish),
                  ),
                  DropdownMenuItem(
                    value: 'pt-BR',
                    child: Text(l10n.languagePortuguese),
                  ),
                ],
                onChanged: (tag) => unawaited(
                  controller.setLocale(switch (tag) {
                    'en' => const Locale('en'),
                    'pt-BR' => const Locale('pt', 'BR'),
                    _ => null,
                  }),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              _Heading(text: l10n.settingsPlayback),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.opensPlayerOnPlay,
                title: Text(l10n.settingsOpensPlayerOnPlay),
                onChanged: (value) =>
                    unawaited(controller.setOpensPlayerOnPlay(value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.rescansAtStartup,
                title: Text(l10n.settingsRescansAtStartup),
                onChanged: (value) =>
                    unawaited(controller.setRescansAtStartup(value)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.settingsVolume, style: theme.textTheme.bodyMedium),
              Slider(
                value: preferences.volume,
                onChanged: (value) => unawaited(controller.setVolume(value)),
              ),

              if (preferences.unsaved) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.settingsUnsaved,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // One button, and it closes: every control in here applies the moment
        // it is touched, so there is nothing to accept and nothing to cancel.
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

/// A heading over a group of preferences.
class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
