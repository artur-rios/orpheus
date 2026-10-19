import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../playback/domain/music_layout.dart';
import '../../playback/presentation/music_browser.dart';
import '../../shell/presentation/async_state_view.dart';
import '../domain/playlist.dart';
import 'playlist_cover.dart';
import 'playlist_menu.dart';
import 'playlist_names.dart';
import 'playlist_view.dart';

/// The Playlists area.
///
/// The owner's playlists, the most recently changed first, as rows or tiles —
/// the same choice the albums follow — and, once one is opened, that playlist.
///
/// Above them, while the preference shows them, the *Auto playlists* section:
/// *Favourites lately* and *All-time favourites*, then *Your playlists*. The
/// section stands on its own: it is there when the owner has no playlists
/// (theirs then say so in a line, not the whole page) and when their
/// playlists could not be read (above that failure). A small loading row
/// stands in for it while the library is read, and it is not shown at all
/// when the library could not be.
///
/// Which one is open is [openPlaylistProvider]'s, not this widget's, so that
/// Back can close it from the shell. An id that names no playlist — one
/// deleted while it was open, or an auto playlist since hidden — reads as
/// none open: the list.
class PlaylistsView extends ConsumerWidget {
  /// Creates the area.
  const PlaylistsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Before the owner's playlists' state: an auto playlist opens whatever
    // became of theirs, and one of theirs is only open once they are read.
    if (ref.watch(openPlaylistProvider) != null) return const PlaylistView();

    final playlists = ref.watch(playlistsControllerProvider);
    final autos = ref.watch(autoPlaylistsProvider);
    // None while the preference hides them, and none from a library that
    // could not be read; the loading row while it is being read.
    final showsAutos = switch (autos) {
      AsyncData(:final value) => value.isNotEmpty,
      AsyncError() => false,
      _ => true,
    };
    if (showsAutos) return _Sections(autos: autos, playlists: playlists);

    // The failure, and nothing else: while the stored playlists could not be
    // read every change is refused, so there is no *New playlist* to offer.
    return AsyncStateView<List<Playlist>>(
      value: playlists,
      onRetry: () => ref.invalidate(playlistsControllerProvider),
      builder: (context, all) => all.isEmpty
          ? const _NoPlaylists()
          : _PlaylistList(playlists: mostRecentFirst(all)),
    );
  }
}

/// The playlists, under the button that makes another.
class _PlaylistList extends ConsumerWidget {
  const _PlaylistList({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(musicLayoutControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => unawaited(startNewPlaylist(context, ref)),
              icon: const Icon(Icons.add),
              label: Text(l10n.playlistNew),
            ),
            const Spacer(),
            MusicLayoutSwitcher(selected: layout),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: CustomScrollView(
            slivers: [_Playlists(playlists: playlists, layout: layout)],
          ),
        ),
      ],
    );
  }
}

/// *Auto playlists*, then *Your playlists*: the tab while the auto playlists
/// are shown, in one scroll.
class _Sections extends ConsumerWidget {
  const _Sections({required this.autos, required this.playlists});

  /// The auto playlists, or their loading.
  final AsyncValue<List<Playlist>> autos;

  /// The owner's playlists, however reading them went.
  final AsyncValue<List<Playlist>> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(musicLayoutControllerProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(child: _Heading(text: l10n.autoPlaylistSection)),
              MusicLayoutSwitcher(selected: layout),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        switch (autos) {
          AsyncData(:final value) => _Playlists(
            playlists: [for (final playlist in value) shownAs(playlist, l10n)],
            layout: layout,
          ),
          _ => const SliverToBoxAdapter(child: _LoadingRow()),
        },
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(child: _Heading(text: l10n.autoPlaylistYours)),
              // Beside playlists there are: with none, the line that says so
              // offers it, and with them unreadable nothing can be made.
              if (playlists case AsyncData(:final value) when value.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(startNewPlaylist(context, ref)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.playlistNew),
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        switch (playlists) {
          AsyncData(:final value) when value.isNotEmpty => _Playlists(
            playlists: mostRecentFirst(value),
            layout: layout,
          ),
          AsyncData() => const SliverToBoxAdapter(
            child: _NoPlaylists(inline: true),
          ),
          // Loading, or the failure with its retry — below the section,
          // which does not depend on them.
          _ => SliverToBoxAdapter(
            child: AsyncStateView<List<Playlist>>(
              value: playlists,
              onRetry: () => ref.invalidate(playlistsControllerProvider),
              builder: (context, _) => const SizedBox.shrink(),
            ),
          ),
        },
      ],
    );
  }
}

/// A section's heading in the tab.
class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// What stands in for the auto playlists while the library is read.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Semantics(
      label: AppLocalizations.of(context).loading,
      child: const LinearProgressIndicator(),
    ),
  );
}

/// [playlists] as rows or tiles, as [layout] says, to go in a scroll.
class _Playlists extends StatelessWidget {
  const _Playlists({required this.playlists, required this.layout});

  final List<Playlist> playlists;
  final MusicLayout layout;

  @override
  Widget build(BuildContext context) => switch (layout) {
    MusicLayout.list => _Rows(playlists: playlists),
    MusicLayout.grid => _Tiles(playlists: playlists),
  };
}

/// One row per playlist.
class _Rows extends ConsumerWidget {
  const _Rows({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SliverList.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];

        return PlaylistMenu(
          // By id: the list reorders itself as playlists change, and a menu
          // or a cover must stay with its own playlist when it moves.
          key: ValueKey(playlist.id),
          playlist: playlist,
          builder: (context, menu) => ListTile(
            leading: PlaylistCover(playlist: playlist, side: 44),
            title: Text(playlist.name),
            subtitle: Text(l10n.playlistSongCount(playlist.entries.length)),
            trailing: _MenuButton(menu: menu),
            onTap: () => _open(ref, playlist),
          ),
        );
      },
    );
  }
}

/// One tile per playlist, the picture first, as the albums' tiles are.
class _Tiles extends ConsumerWidget {
  const _Tiles({required this.playlists});

  final List<Playlist> playlists;

  /// How wide a tile may grow before the grid takes another column — the
  /// albums' figure, so the two walls look alike.
  static const double _extent = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _extent,
        childAspectRatio: 3 / 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];

        return PlaylistMenu(
          key: ValueKey(playlist.id),
          playlist: playlist,
          builder: (context, menu) => Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(ref, playlist),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) => PlaylistCover(
                          playlist: playlist,
                          side: constraints.biggest.shortestSide,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      playlist.name,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.playlistSongCount(playlist.entries.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _MenuButton(menu: menu),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The ⋮ button, opening the [PlaylistMenu] around the row or tile.
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.menu});

  final MenuController menu;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).playlistActions,
    icon: const Icon(Icons.more_vert),
    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
  );
}

/// Opening rather than playing, as an album row does: playing is inside,
/// where it is a decision rather than something a mis-aimed tap does.
void _open(WidgetRef ref, Playlist playlist) =>
    ref.read(playlistBrowseProvider.notifier).open(playlist.id);

/// No playlists yet, and the way to make the first.
///
/// The whole page when it is all the tab has; [inline], a line and the
/// button under *Your playlists*, below the auto playlists.
class _NoPlaylists extends ConsumerWidget {
  const _NoPlaylists({this.inline = false});

  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (inline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.playlistEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => unawaited(startNewPlaylist(context, ref)),
              icon: const Icon(Icons.add),
              label: Text(l10n.playlistNew),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.playlist_play_outlined,
                size: AppSpacing.xxl,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.playlistEmpty,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => unawaited(startNewPlaylist(context, ref)),
                icon: const Icon(Icons.add),
                label: Text(l10n.playlistNew),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
