import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/playback/presentation/media_session_names_scope.dart';
import 'features/shell/application/shell_controller.dart';
import 'features/shell/domain/shell_destination.dart';
import 'features/shell/presentation/shell_screen.dart';
import 'features/updates/presentation/update_prompt.dart';

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

    // Inside the `MaterialApp`, because the prompt it raises is a dialog and a
    // dialog needs a navigator over whatever asked for one.
    home: const UpdatePromptScope(child: _ShellWithBack()),
  );
}

/// The shell, with the system back gesture wired to the navigation of
/// whichever library area is showing — Music's, Genres' own, or the open
/// playlist's.
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
    final genre = ref.watch(genreBrowseControllerProvider);
    // Open and still there: a playlist deleted while it was open leaves its
    // id behind, and the tab shows the list of them then — so there is no
    // level for back to climb, and a press spent closing an id nobody can see
    // would look like it did nothing.
    final inPlaylist =
        destination == ShellDestination.playlists &&
        ref.watch(openPlaylistProvider) != null;
    // The same test the shell uses to decide results are showing: a single
    // character left in the field shows the listing, and a back press that
    // spent itself clearing an invisible term would look like it did nothing.
    final searching = isSearchable(ref.watch(searchTermProvider));

    // A selection only lives while its list is on screen, so an active one is
    // normally a visible one — and the first thing back ends. (A reload in
    // flight can keep one a moment after its list has gone; back ending it
    // then is harmless.)
    final selecting = ref.watch(songSelectionProvider).isActive;

    final canGoUp =
        selecting ||
        searching ||
        (destination == ShellDestination.music &&
            (browse.inAlbum || browse.inArtist)) ||
        // Inside a genre at all, not only inside a drill: the list of genres
        // is a level above the genre's own top, and back is how a phone gets
        // there.
        (destination == ShellDestination.genres && genre.inGenre) ||
        inPlaylist;

    return PopScope(
      canPop: !canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // Ending the selection leaves the list where it is: the album is
        // still open and the results are still showing.
        if (selecting) {
          ref.read(songSelectionProvider.notifier).clear();

          return;
        }

        // A search covers whatever area is behind it, so clearing it is the
        // first thing back does — the owner is looking at results, and what
        // they want back is the listing.
        if (searching) {
          ref.read(searchTermProvider.notifier).clear();

          return;
        }

        // The back of the area that is showing: each keeps its own place, and
        // stepping out of a record under Rock must not move Music.
        if (destination == ShellDestination.genres) {
          ref.read(genreBrowseControllerProvider.notifier).back();
        } else if (destination == ShellDestination.playlists) {
          ref.read(playlistBrowseProvider.notifier).close();
        } else {
          ref.read(musicBrowseControllerProvider.notifier).back();
        }
      },
      child: const MediaSessionNamesScope(child: ShellScreen()),
    );
  }
}
