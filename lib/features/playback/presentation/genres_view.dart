import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../autofill/presentation/batch_autofill_launcher.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../shell/presentation/async_state_view.dart';
import 'music_browser.dart';
import 'music_display_name.dart';
import 'music_library_view.dart';
import 'music_scope.dart';

/// The Genres area.
///
/// A list of the genres the library's tags name, and, once one is opened, the
/// Music tab's own browser over that genre's part of the library. The same
/// browser rather than a second one written for genres, so that an owner who
/// has learned to find a record under Music finds it the same way under Rock.
///
/// Its place is its own: drilling into an artist here moves nothing in Music,
/// which is why the browser below is handed the genre's navigator and drawn
/// inside a [MusicScope] naming it.
class GenresView extends ConsumerWidget {
  /// Creates the area.
  const GenresView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(musicLibraryControllerProvider);
    final genre = ref.watch(genreBrowseControllerProvider);
    final entries = library.value?.entries ?? const <MusicEntry>[];

    if (!genre.inGenre) {
      return AsyncStateView<MusicCatalog>(
        value: library,
        onRetry: () => ref.invalidate(musicLibraryControllerProvider),
        isEmpty: (catalog) => catalog.isEmpty,
        emptyBuilder: (context) => const MusicLibraryEmpty(),
        builder: (context, catalog) => _GenreList(entries: catalog.entries),
      );
    }

    final navigator = ref.read(genreBrowseControllerProvider.notifier);
    final key = genre.genre;
    final name = key == null
        ? l10n.genreUnknown
        : (genreNamesIn(entries)[key] ?? key);
    final within = genreLibrary(key, entries);
    final tracks = tracksOfGenre(key, entries);

    return MusicScope(
      navigator: navigator,
      within: within,
      child: MusicBrowser(
        state: genre.music,
        library: within,
        // Only the tracks tagged with the genre, though its records are
        // browsed whole: Songs is a list of tracks, and a track that is not
        // Rock is not a Rock song because it shares a record with one.
        // Sorted only while Songs is showing, for the reason the Music tab
        // gives.
        songs: MusicBrowser.showsSongs(genre.music)
            ? songsIn(tracks)
            : const [],
        navigator: navigator,
        rootLabel: name,
        leadingCrumbs: [
          (label: l10n.destinationGenres, onTap: navigator.closeGenre),
        ],
        fallbackLibrary: entries,
        // The genre's tracks, as its own row's shuffle plays them — not
        // everything, which is what the same button means under Music.
        onShuffle: () => unawaited(
          ref
              .read(audioPlaybackControllerProvider.notifier)
              .playAll(
                name: name,
                tracks: [for (final entry in tracks) entry.file],
                shuffled: true,
              ),
        ),
        shuffleTooltip: l10n.genreShuffle,
        onAutofill: () => unawaited(startBatchAutofill(context, ref, tracks)),
        selectionPlace: ('genre', key),
      ),
    );
  }
}

/// Every genre, one row each.
///
/// Rows alone, with no controls bar above them: there is no view to switch
/// between until a genre is open, and the play and shuffle a bar would offer
/// are on each row, where they say which genre they mean.
class _GenreList extends ConsumerWidget {
  const _GenreList({required this.entries});

  final List<MusicEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final genres = genresIn(entries);

    return ListView.builder(
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        final name = genre.name ?? l10n.genreUnknown;
        final count = l10n.musicTrackCount(genre.tracks.length);
        final duration = genre.duration;

        return _GenreMenu(
          genre: genre,
          builder: (context, menu) => ListTile(
            title: Text(name),
            // The count alone where any length is unknown: a total that skipped
            // the tracks it could not measure would be a number nobody can read.
            subtitle: Text(
              duration == null
                  ? count
                  : l10n.genreRowSummary(
                      count,
                      formatPlaybackPosition(duration),
                    ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.genrePlay,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _play(ref, genre, name, shuffled: false),
                ),
                IconButton(
                  tooltip: l10n.genreShuffle,
                  icon: const Icon(Icons.shuffle),
                  onPressed: () => _play(ref, genre, name, shuffled: true),
                ),
                IconButton(
                  tooltip: l10n.musicGroupActions,
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ],
            ),
            // Opening rather than playing, as an artist row does: playing is on
            // the buttons beside it, where it is a decision rather than
            // something a mis-aimed click does.
            onTap: () => ref
                .read(genreBrowseControllerProvider.notifier)
                .openGenre(genre.key),
          ),
        );
      },
    );
  }

  /// Plays [genre]'s tracks — only those tagged with it, by track rather than
  /// by record — under [name], the name its row shows.
  void _play(
    WidgetRef ref,
    GenreGroup genre,
    String name, {
    required bool shuffled,
  }) => unawaited(
    ref
        .read(audioPlaybackControllerProvider.notifier)
        .playAll(
          name: name,
          tracks: [for (final entry in genre.tracks) entry.file],
          shuffled: shuffled,
        ),
  );
}

/// A genre's own actions: autofill.
///
/// Opened by right-click, long press, or the ⋮ button on the row, as an
/// album's menu is. The row is built by [builder] and handed the
/// [MenuController], so the button sits wherever the row wants it.
class _GenreMenu extends ConsumerWidget {
  const _GenreMenu({required this.genre, required this.builder});

  /// The genre the menu acts on.
  final GenreGroup genre;

  /// The row, wired to open the menu through the controller it is given.
  final Widget Function(BuildContext context, MenuController menu) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.auto_fix_high_outlined),
          // Only the tracks tagged with the genre, as its play buttons queue.
          onPressed: () =>
              unawaited(startBatchAutofill(context, ref, genre.tracks)),
          child: Text(l10n.autofillAction),
        ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        onLongPressStart: (details) =>
            controller.open(position: details.localPosition),
        child: builder(context, controller),
      ),
    );
  }
}
