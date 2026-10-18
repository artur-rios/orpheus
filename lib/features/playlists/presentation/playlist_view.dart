import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/audio_file.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../playback/presentation/music_display_name.dart';
import '../../shell/presentation/async_state_view.dart';
import '../domain/playlist.dart';
import 'playlist_cover.dart';
import 'playlist_menu.dart';
import 'playlist_track_list.dart';

/// The open playlist: its name and the way back, its picture and what it
/// holds, *Play* and *Shuffle*, and its songs.
///
/// Which playlist that is is [openPlaylistProvider]'s; with none open this
/// draws nothing, and the tab shows the list of them instead.
///
/// Everything below the name waits for the library: whether a song is
/// missing is read off the catalog, and a catalog still being read would
/// make every row look missing.
class PlaylistView extends ConsumerWidget {
  /// Creates the view.
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(openPlaylistProvider);
    if (playlist == null) return const SizedBox.shrink();

    final library = ref.watch(musicLibraryControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TitleRow(playlist: playlist),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AsyncStateView<MusicCatalog>(
            value: library,
            onRetry: () => ref.invalidate(musicLibraryControllerProvider),
            builder: (context, catalog) =>
                _Loaded(playlist: playlist, songs: catalog.byPath),
          ),
        ),
      ],
    );
  }
}

/// The way back to the list, the name, and the playlist's own menu.
class _TitleRow extends ConsumerWidget {
  const _TitleRow({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: l10n.playlistBackToList,
          icon: const Icon(Icons.arrow_back),
          onPressed: ref.read(playlistBrowseProvider.notifier).close,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            playlist.name,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PlaylistMenu(
          playlist: playlist,
          builder: (context, menu) => IconButton(
            tooltip: l10n.playlistActions,
            icon: const Icon(Icons.more_vert),
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
        ),
      ],
    );
  }
}

/// The header and the rows, once the library is known.
class _Loaded extends ConsumerWidget {
  const _Loaded({required this.playlist, required this.songs});

  final Playlist playlist;
  final Map<String, MusicEntry> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final present = <AudioFile>[
      for (final entry in playlist.entries)
        if (songs[entry.path] case final song?) song.file,
    ];
    final count = l10n.playlistSongCount(playlist.entries.length);
    final length = _lengthOf(playlist, songs);

    void play({required bool shuffled}) => unawaited(
      ref
          .read(audioPlaybackControllerProvider.notifier)
          .playAll(name: playlist.name, tracks: present, shuffled: shuffled),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PlaylistCover(playlist: playlist, side: 96),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    length == Duration.zero
                        ? count
                        : l10n.playlistSummary(
                            count,
                            formatPlaybackPosition(length),
                          ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Wrapping rather than overflowing, for a phone's width
                  // in a language with long words for these.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        // From the first song the library has.
                        onPressed: present.isEmpty
                            ? null
                            : () => play(shuffled: false),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.audioPlay),
                      ),
                      OutlinedButton.icon(
                        onPressed: present.isEmpty
                            ? null
                            : () => play(shuffled: true),
                        icon: const Icon(Icons.shuffle),
                        label: Text(l10n.playlistShuffle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: PlaylistTrackList(playlist: playlist, songs: songs),
        ),
      ],
    );
  }

  /// How long the playlist lasts: each present song's length as the library
  /// knows it, and a missing one's as it was when it was added.
  static Duration _lengthOf(Playlist playlist, Map<String, MusicEntry> songs) {
    var total = Duration.zero;
    for (final entry in playlist.entries) {
      final length = songs[entry.path]?.duration ?? entry.duration;
      if (length != null) total += length;
    }

    return total;
  }
}
