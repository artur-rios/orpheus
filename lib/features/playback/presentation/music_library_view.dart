import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../shell/domain/shell_destination.dart';
import '../../shell/presentation/async_state_view.dart';
import '../application/music_browse_controller.dart';
import '../domain/music_layout.dart';
import 'music_display_name.dart';
import 'music_rows.dart';

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
    final library = ref.watch(musicLibraryControllerProvider);
    final browse = ref.watch(musicBrowseControllerProvider);
    final layout = ref.watch(musicLayoutControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Controls(view: browse.view, layout: layout),
        const SizedBox(height: AppSpacing.sm),
        _Breadcrumb(state: browse),
        Expanded(
          child: AsyncStateView<MusicCatalog>(
            value: library,
            onRetry: () => ref.invalidate(musicLibraryControllerProvider),
            isEmpty: (catalog) => catalog.isEmpty,
            emptyBuilder: (context) => const _Empty(),
            builder: (context, catalog) => _List(
              state: browse,
              library: catalog.entries,
              layout: layout,
            ),
          ),
        ),
      ],
    );
  }
}

/// The view switcher, the shuffle button and the layout switcher.
///
/// One row wherever one row holds them, and two on a phone, where it does not.
/// The three of them want about 545 logical pixels together — 585 in
/// Portuguese, whose words for these are longer — and a 393-pixel handset
/// offers 361 between its margins. What that shortfall used to buy was a
/// segmented control squeezed until its labels wrapped mid-word: "Albu / ms".
///
/// Reflowed rather than reshaped. Nothing here changes what it is or what it
/// says on a narrow screen — the switcher takes a row of its own, at the full
/// width, which is what a segmented control does on a phone anyway, and the
/// two controls that are already icons sit under its right edge. The tiers
/// above it are untouched.
class _Controls extends StatelessWidget {
  const _Controls({required this.view, required this.layout});

  final MusicView view;
  final MusicLayout layout;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoint.from(context).usesBottomNavigation) {
      return Row(
        children: [
          Expanded(child: _ViewSwitcher(selected: view)),
          const _ShuffleEverythingButton(),
          _LayoutSwitcher(selected: layout),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewSwitcher(selected: view, fillsWidth: true),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _ShuffleEverythingButton(),
            _LayoutSwitcher(selected: layout),
          ],
        ),
      ],
    );
  }
}

/// Which list the area is showing, given where the owner has drilled to.
class _List extends ConsumerWidget {
  const _List({
    required this.state,
    required this.library,
    required this.layout,
  });

  final MusicBrowseState state;
  final List<MusicEntry> library;

  /// Rows or tiles, the same choice wherever the owner has drilled to: a
  /// layout that changed under them as they went into a record would be a
  /// setting they had to re-make at every level.
  final MusicLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (state) {
    MusicBrowseState(inAlbum: true) => MusicTrackList(
      entries: tracksOfAlbum(state.album, state.artist, library),
      numbered: true,
    ),
    MusicBrowseState(view: MusicView.artists, inArtist: true) => MusicGroupList(
      groups: albumsOfArtist(state.artist, library),
      kind: MusicGroupKind.album,
      layout: layout,
    ),
    MusicBrowseState(view: MusicView.artists) => MusicGroupList(
      groups: artistsIn(library),
      kind: MusicGroupKind.artist,
      layout: layout,
    ),
    MusicBrowseState(view: MusicView.albums) => MusicGroupList(
      groups: albumsIn(library),
      kind: MusicGroupKind.album,
      layout: layout,
    ),
    MusicBrowseState(view: MusicView.songs) => MusicTrackList(
      entries: songsIn(library),
      numbered: false,
    ),
  };
}

/// Rows or tiles, remembered.
class _LayoutSwitcher extends ConsumerWidget {
  const _LayoutSwitcher({required this.selected});

  final MusicLayout selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SegmentedButton<MusicLayout>(
      segments: [
        for (final layout in MusicLayout.values)
          ButtonSegment(
            value: layout,
            icon: Icon(layout.icon),
            tooltip: layout.label(l10n),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (chosen) => unawaited(
        ref.read(musicLayoutControllerProvider.notifier).choose(chosen.single),
      ),
    );
  }
}

/// Plays the whole library in an order nobody chose.
///
/// Beside the views rather than inside one of them: an owner who wants
/// something to play is not browsing, and making them first pick a record to
/// shuffle would be asking them the question they opened this to avoid.
class _ShuffleEverythingButton extends ConsumerWidget {
  const _ShuffleEverythingButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: l10n.audioShuffleAll,
      icon: const Icon(Icons.shuffle),
      onPressed: () => unawaited(
        ref
            .read(audioPlaybackControllerProvider.notifier)
            .playEverythingShuffled(label: l10n.audioShuffleAllLabel),
      ),
    );
  }
}

/// How each layout presents itself in the switcher.
extension _MusicLayoutPresentation on MusicLayout {
  IconData get icon => switch (this) {
    MusicLayout.list => Icons.view_list_outlined,
    MusicLayout.grid => Icons.grid_view_outlined,
  };

  String label(AppLocalizations l10n) => switch (this) {
    MusicLayout.list => l10n.layoutList,
    MusicLayout.grid => l10n.layoutGrid,
  };
}

/// The three views.
class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher({required this.selected, this.fillsWidth = false});

  final MusicView selected;

  /// Whether it spreads across everything it is given.
  ///
  /// It does on a phone, where it has a row to itself and the three views
  /// divide it evenly — which is what stops the labels wrapping, since each
  /// segment is then a third of the row rather than a third of what two other
  /// controls left over. Everywhere else it is one of three controls sharing a
  /// row, and takes only the width its words need.
  final bool fillsWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final button = SegmentedButton<MusicView>(
      segments: [
        for (final view in MusicView.values)
          ButtonSegment(value: view, label: Text(view.label(l10n))),
      ],
      selected: {selected},
      showSelectedIcon: false,
      // What makes it divide the row rather than sit at its natural width.
      // `Alignment.center` would not: an [Align] loosens what it passes down,
      // and a segmented button given a loose width takes only what its
      // longest label asks for.
      expandedInsets: fillsWidth ? EdgeInsets.zero : null,
      onSelectionChanged: (chosen) =>
          ref.read(musicBrowseControllerProvider.notifier).show(chosen.single),
    );

    return fillsWidth
        ? button
        : Align(alignment: Alignment.centerLeft, child: button);
  }
}

/// How each view names itself.
extension _MusicViewPresentation on MusicView {
  String label(AppLocalizations l10n) => switch (this) {
    MusicView.artists => l10n.musicViewArtists,
    MusicView.albums => l10n.musicViewAlbums,
    MusicView.songs => l10n.musicViewSongs,
  };
}

/// How far in the owner is, and the way back out.
class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.state});

  final MusicBrowseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(musicBrowseControllerProvider.notifier);

    final crumbs = <(String, VoidCallback?)>[
      (
        l10n.musicBreadcrumbRoot,
        state.inArtist || state.inAlbum ? controller.upToArtists : null,
      ),
      // The record's artist, on both paths into a record: whose record it is
      // is a fact about the record, not about how the owner reached it — so on
      // the Albums path, where no artist was ever drilled through, this crumb
      // is the only place an ordinary record's artist is named at all.
      if (state.inArtist || state.inAlbum)
        (
          state.artist ?? l10n.musicUnknownArtist,
          // A control only where it leads somewhere the owner has been: the
          // Artists path came through this artist's own list of albums and
          // goes back to it. Reached from Albums there is no such list to
          // return to — inventing one would take the owner somewhere they
          // never were — so the name is plain text.
          state.inArtist && state.inAlbum ? controller.upToArtist : null,
        ),
      if (state.inAlbum) (state.album ?? l10n.musicUnknownAlbum, null),
    ];

    if (crumbs.length == 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (index, (label, onTap)) in crumbs.indexed) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text('›', style: theme.textTheme.bodySmall),
                ),
              // The last crumb is where the owner already is, so it is text
              // rather than a control that would do nothing.
              if (onTap == null)
                Text(label, style: theme.textTheme.bodySmall)
              else
                TextButton(onPressed: onTap, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nothing has been scanned.
class _Empty extends ConsumerWidget {
  const _Empty();

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
