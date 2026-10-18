import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../application/music_browse_controller.dart';
import '../application/music_navigator.dart';
import '../domain/music_layout.dart';
import 'music_display_name.dart';
import 'music_rows.dart';

/// One step of the breadcrumb: what it says, and where it leads — `null` for
/// a crumb that is only text.
typedef MusicCrumb = ({String label, VoidCallback? onTap});

/// Artists, Albums and Songs, the drills into them, and the way back out.
///
/// Not the Music tab itself but what the Music tab draws, so that a genre
/// opened in Genres is browsed exactly as the whole library is: the same
/// views, the same rows and tiles, the same breadcrumb. What differs between
/// the two is handed in — what is browsed, which navigator keeps the owner's
/// place, what the root of the breadcrumb is called and what shuffle plays.
///
/// The rows below it navigate and play through the nearest `MusicScope`, so
/// a browser away from the Music tab is drawn inside one naming the same
/// [navigator].
class MusicBrowser extends ConsumerWidget {
  /// Creates the browser.
  const MusicBrowser({
    required this.state,
    required this.library,
    required this.songs,
    required this.navigator,
    required this.rootLabel,
    required this.onShuffle,
    required this.shuffleTooltip,
    this.leadingCrumbs = const [],
    this.fallbackLibrary,
    this.listFrame,
    super.key,
  });

  /// Where the owner is.
  final MusicBrowseState state;

  /// What Artists, Albums and an open artist or record are drawn from.
  final List<MusicEntry> library;

  /// The Songs view, already in the order it is shown in.
  ///
  /// Handed in rather than derived from [library]: under a genre, Songs lists
  /// only the tracks tagged with it, while [library] holds the genre's records
  /// whole.
  ///
  /// Read only where [showsSongs] says the Songs list is on screen, and a
  /// caller passes `const []` everywhere else: putting a library in song
  /// order is a sort of every track, and this browser is rebuilt on every
  /// drill, view switch and change of layout.
  final List<MusicEntry> songs;

  /// Whether [state] puts the Songs list on screen — the one place [songs]
  /// is read.
  ///
  /// An open record shows its own tracks whichever view it was opened from;
  /// every other state of the Songs view is the list.
  static bool showsSongs(MusicBrowseState state) =>
      !state.inAlbum && state.view == MusicView.songs;

  /// What the view switcher and the breadcrumb steer.
  final MusicNavigator navigator;

  /// The breadcrumb's own root — what the top of this browser is called.
  final String rootLabel;

  /// Crumbs drawn before [rootLabel], each leading where its own `onTap`
  /// says.
  ///
  /// Where there are any, the breadcrumb is shown at the top as well: it is
  /// then the way back out of the browser, not only out of a drill. Where
  /// there are none, it is hidden at the top, where it would say nothing but
  /// the name of the view the owner is already in.
  final List<MusicCrumb> leadingCrumbs;

  /// Where an open record with no tracks in [library] is drawn from instead,
  /// or `null` to draw it from [library] alone.
  ///
  /// A record that lost a genre's tag while it was open under that genre is
  /// still the record the owner is looking at; drawing it from the genre
  /// would empty the screen under its own name.
  final List<MusicEntry>? fallbackLibrary;

  /// What the controls bar's shuffle button plays.
  final VoidCallback onShuffle;

  /// What the controls bar's shuffle button says it does.
  final String shuffleTooltip;

  /// What the list is drawn inside, or `null` for the list alone.
  ///
  /// The Music tab's: its loading, failure and empty states take the list's
  /// place under the controls and the breadcrumb, which stay on screen
  /// through all of them — the owner can still choose a view, or shuffle,
  /// while the library is read.
  final Widget Function(BuildContext context, Widget list)? listFrame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(musicLayoutControllerProvider);
    final list = _List(
      state: state,
      library: library,
      songs: songs,
      fallbackLibrary: fallbackLibrary,
      layout: layout,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Controls(
          view: state.view,
          layout: layout,
          navigator: navigator,
          onShuffle: onShuffle,
          shuffleTooltip: shuffleTooltip,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Breadcrumb(
          state: state,
          navigator: navigator,
          rootLabel: rootLabel,
          leadingCrumbs: leadingCrumbs,
        ),
        Expanded(child: listFrame?.call(context, list) ?? list),
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
  const _Controls({
    required this.view,
    required this.layout,
    required this.navigator,
    required this.onShuffle,
    required this.shuffleTooltip,
  });

  final MusicView view;
  final MusicLayout layout;
  final MusicNavigator navigator;
  final VoidCallback onShuffle;
  final String shuffleTooltip;

  @override
  Widget build(BuildContext context) {
    final shuffle = IconButton(
      tooltip: shuffleTooltip,
      icon: const Icon(Icons.shuffle),
      onPressed: onShuffle,
    );

    if (!Breakpoint.from(context).usesBottomNavigation) {
      return Row(
        children: [
          Expanded(
            child: _ViewSwitcher(selected: view, navigator: navigator),
          ),
          shuffle,
          _LayoutSwitcher(selected: layout),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewSwitcher(selected: view, navigator: navigator, fillsWidth: true),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            shuffle,
            _LayoutSwitcher(selected: layout),
          ],
        ),
      ],
    );
  }
}

/// Which list the browser is showing, given where the owner has drilled to.
class _List extends StatelessWidget {
  const _List({
    required this.state,
    required this.library,
    required this.songs,
    required this.fallbackLibrary,
    required this.layout,
  });

  final MusicBrowseState state;
  final List<MusicEntry> library;
  final List<MusicEntry> songs;
  final List<MusicEntry>? fallbackLibrary;

  /// Rows or tiles, the same choice wherever the owner has drilled to: a
  /// layout that changed under them as they went into a record would be a
  /// setting they had to re-make at every level.
  final MusicLayout layout;

  /// The open record's tracks: from [library], or from [fallbackLibrary]
  /// where [library] no longer holds any of them.
  List<MusicEntry> _recordTracks() {
    final tracks = tracksOfAlbum(state.album, state.artist, library);
    final fallback = fallbackLibrary;

    return tracks.isEmpty && fallback != null
        ? tracksOfAlbum(state.album, state.artist, fallback)
        : tracks;
  }

  @override
  Widget build(BuildContext context) => switch (state) {
    MusicBrowseState(inAlbum: true) => MusicTrackList(
      entries: _recordTracks(),
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
      entries: songs,
      numbered: false,
    ),
  };
}

/// Rows or tiles, remembered.
///
/// One choice for every browser, not one per screen: an owner who prefers a
/// wall of sleeves prefers it under a genre too.
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
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.selected,
    required this.navigator,
    this.fillsWidth = false,
  });

  final MusicView selected;
  final MusicNavigator navigator;

  /// Whether it spreads across everything it is given.
  ///
  /// It does on a phone, where it has a row to itself and the three views
  /// divide it evenly — which is what stops the labels wrapping, since each
  /// segment is then a third of the row rather than a third of what two other
  /// controls left over. Everywhere else it is one of three controls sharing a
  /// row, and takes only the width its words need.
  final bool fillsWidth;

  @override
  Widget build(BuildContext context) {
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
      onSelectionChanged: (chosen) => navigator.show(chosen.single),
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
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.state,
    required this.navigator,
    required this.rootLabel,
    required this.leadingCrumbs,
  });

  final MusicBrowseState state;
  final MusicNavigator navigator;
  final String rootLabel;
  final List<MusicCrumb> leadingCrumbs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final drilled = state.inArtist || state.inAlbum;

    // At the top with nothing before the root, the breadcrumb would be the
    // root alone: the name of the view the owner is already in.
    if (!drilled && leadingCrumbs.isEmpty) return const SizedBox.shrink();

    final crumbs = <MusicCrumb>[
      ...leadingCrumbs,
      (label: rootLabel, onTap: drilled ? navigator.upToArtists : null),
      // The record's artist, on both paths into a record: whose record it is
      // is a fact about the record, not about how the owner reached it — so on
      // the Albums path, where no artist was ever drilled through, this crumb
      // is the only place an ordinary record's artist is named at all.
      if (drilled)
        (
          label: state.artist ?? l10n.musicUnknownArtist,
          // A control only where it leads somewhere the owner has been: the
          // Artists path came through this artist's own list of albums and
          // goes back to it. Reached from Albums there is no such list to
          // return to — inventing one would take the owner somewhere they
          // never were — so the name is plain text.
          onTap: state.inArtist && state.inAlbum ? navigator.upToArtist : null,
        ),
      if (state.inAlbum)
        (label: state.album ?? l10n.musicUnknownAlbum, onTap: null),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (index, (:label, :onTap)) in crumbs.indexed) ...[
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
