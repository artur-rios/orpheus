import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/playback/presentation/media_session_names_scope.dart';
import 'features/shell/domain/shell_destination.dart';
import 'features/shell/presentation/shell_screen.dart';

/// The application root.
///
/// It owns three things and no more: the themes, the locales, and the shell.
/// Everything the owner actually does lives under the shell.
class OrpheusApp extends ConsumerWidget {
  /// Creates the root widget.
  const OrpheusApp({super.key});

  /// The languages the application ships.
  ///
  /// Brazilian Portuguese is declared with its country code even though the
  /// catalog is the base `pt` file — that is the locale the product supports,
  /// and Flutter resolves it to the `pt` messages.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('pt', 'BR'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,

    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),

    locale: ref.watch(localeProvider),
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],

    home: const _ShellWithBack(),
  );
}

/// The shell, with the system back gesture wired to the music area's own
/// navigation.
///
/// On Android, back is how an owner leaves a record — there is no breadcrumb
/// wide enough to be worth showing on a phone, and a back gesture that closed
/// the application from inside an album would be the wrong answer to what they
/// meant. Where there is nothing to go back to, the gesture is left alone and
/// does whatever the platform does with it.
class _ShellWithBack extends ConsumerWidget {
  const _ShellWithBack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(shellControllerProvider);
    final browse = ref.watch(musicBrowseControllerProvider);
    final searching = ref.watch(searchTermProvider).isNotEmpty;

    final canGoUp =
        searching ||
        (destination == ShellDestination.music &&
            (browse.inAlbum || browse.inArtist));

    return PopScope(
      canPop: !canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // A search covers whatever area is behind it, so clearing it is the
        // first thing back does — the owner is looking at results, and what
        // they want back is the listing.
        if (searching) {
          ref.read(searchTermProvider.notifier).clear();

          return;
        }

        ref.read(musicBrowseControllerProvider.notifier).back();
      },
      child: const MediaSessionNamesScope(child: ShellScreen()),
    );
  }
}
