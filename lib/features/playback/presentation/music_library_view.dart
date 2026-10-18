import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_grouping.dart';
import '../../shell/domain/shell_destination.dart';
import '../../shell/presentation/async_state_view.dart';
import 'music_browser.dart';

/// The music area.
///
/// A library of audio files is never shown as a listing of file names. The
/// catalog holds the title, the artist and the album for every one of these
/// files, and this area shows those; the name on disk appears nowhere in it.
class MusicLibraryView extends ConsumerWidget {
  /// Creates the area.
  const MusicLibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(musicLibraryControllerProvider);
    final browse = ref.watch(musicBrowseControllerProvider);
    final entries = library.value?.entries ?? const [];

    return MusicBrowser(
      state: browse,
      library: entries,
      songs: songsIn(entries),
      navigator: ref.read(musicBrowseControllerProvider.notifier),
      rootLabel: l10n.musicBreadcrumbRoot,
      // The whole library in an order nobody chose. Beside the views rather
      // than inside one of them: an owner who wants something to play is not
      // browsing, and making them first pick a record to shuffle would be
      // asking them the question they opened this to avoid.
      onShuffle: () => unawaited(
        ref
            .read(audioPlaybackControllerProvider.notifier)
            .playEverythingShuffled(label: l10n.audioShuffleAllLabel),
      ),
      shuffleTooltip: l10n.audioShuffleAll,
      // Only the list waits on the library: the controls and the breadcrumb
      // stay above its loading, failure and empty states.
      listFrame: (context, list) => AsyncStateView<MusicCatalog>(
        value: library,
        onRetry: () => ref.invalidate(musicLibraryControllerProvider),
        isEmpty: (catalog) => catalog.isEmpty,
        emptyBuilder: (context) => const MusicLibraryEmpty(),
        builder: (context, catalog) => list,
      ),
    );
  }
}

/// Nothing has been scanned.
///
/// Public because it is the library's empty state wherever the library is
/// browsed, not only in this area: an empty library has no genres either, and
/// what the owner needs from either screen is the way to the folders.
class MusicLibraryEmpty extends ConsumerWidget {
  /// Creates the empty state.
  const MusicLibraryEmpty({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: AppSpacing.xxl,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.musicEmpty,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.musicEmptyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              // The empty state is where an owner actually is when they need
              // the folders screen, so it takes them there rather than telling
              // them where to look for it.
              FilledButton.icon(
                onPressed: () => ref
                    .read(shellControllerProvider.notifier)
                    .go(ShellDestination.folders),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(l10n.foldersAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The width at which the music area stops showing its view labels in full.
///
/// Read by the shell to decide how much padding the area is given: the
/// segmented control, the shuffle button and the layout switcher share one
/// row, and below this they need every pixel of it.
double musicAreaPadding(BuildContext context) =>
    Breakpoint.from(context).usesBottomNavigation
    ? AppSpacing.md
    : AppSpacing.lg;
