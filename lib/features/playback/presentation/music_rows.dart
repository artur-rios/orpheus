import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../autofill/application/autofill_controller.dart';
import '../../autofill/presentation/autofill_launcher.dart';
import '../../autofill/presentation/batch_autofill_launcher.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../playlists/presentation/add_to_playlist.dart';
import '../../tag_editor/presentation/edit_tags_launcher.dart';
import '../application/audio_playback_controller.dart';
import '../application/song_selection_controller.dart';
import '../domain/music_layout.dart';
import 'album_art.dart';
import 'letter_bar.dart';
import 'music_display_name.dart';
import 'music_scope.dart';

/// The artists, or the albums.
///
/// Rows or tiles, as the owner has asked. These are the two views with a
/// picture apiece, and a wall of sleeves is how a shelf of records is actually
/// read; the rows stay because they hold more per screen and say whose a
/// record is in words.
class MusicGroupList extends ConsumerWidget {
  /// Creates the list.
  const MusicGroupList({
    required this.groups,
    required this.kind,
    this.layout = MusicLayout.list,
    this.indexed = false,
    super.key,
  });

  /// What to show.
  final List<MusicGroup> groups;

  /// Whether these are artists or albums.
  final MusicGroupKind kind;

  /// Rows or tiles.
  final MusicLayout layout;

  /// Whether a [LetterBar] stands beside the list.
  ///
  /// For the whole library's artists and albums, which run to hundreds; not
  /// for one artist's records, which fit on a screen or two and are not in an
  /// order a letter would help with.
  final bool indexed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget list(ScrollController? controller) => switch (layout) {
      MusicLayout.grid => _GroupGrid(
        groups: groups,
        kind: kind,
        scroll: controller,
      ),
      MusicLayout.list => _GroupRows(
        groups: groups,
        kind: kind,
        scroll: controller,
      ),
    };

    if (!indexed) return list(null);

    return LetterIndexedScroll(
      names: [for (final group in groups) group.name],
      columnsFor: layout == MusicLayout.grid ? _GroupGrid.columnsFor : null,
      rowSpacing: layout == MusicLayout.grid ? _GroupGrid.spacing : 0,
      builder: (context, controller) => list(controller),
    );
  }
}

/// The rows.
///
/// A builder rather than a column: scrolling cost must not grow with the size
/// of the library, and that applies to a list of albums exactly as it applies
/// to a list of tracks.
class _GroupRows extends ConsumerWidget {
  const _GroupRows({
    required this.groups,
    required this.kind,
    required this.scroll,
  });

  final List<MusicGroup> groups;
  final MusicGroupKind kind;

  /// What scrolls the list, or `null` for its own.
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = musicNavigatorOf(context, ref);

    return ListView.builder(
      controller: scroll,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        // Only an album row needs whose it is — an artist row already is the
        // answer to that question.
        //
        // The album's artist, not the first track's performer: it is what
        // `albumsIn` grouped the record by, so it is what `tracksOfAlbum` has
        // to be drilled in with — a compilation drilled in by one performer
        // would open on a record of one track.
        final artist = group.entries.first.albumArtist;

        return MusicGroupMenu(
          group: group,
          kind: kind,
          builder: (context, menu) => ListTile(
            leading: _GroupArt(group: group, kind: kind, side: 44),
            // One line apiece, so every row is the same height: a long name
            // wrapping onto a second line would make one row taller than the
            // rest, and the letter bar's jump relies on them all matching.
            title: Text(
              musicGroupName(group, l10n, kind: kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              kind == MusicGroupKind.album
                  ? artist ?? l10n.musicUnknownArtist
                  : l10n.musicTrackCount(group.entries.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _GroupActions(group: group, kind: kind, menu: menu),
            // Drilling in rather than playing: playing a whole artist or
            // record is on the buttons beside it, where it is a decision
            // rather than something a mis-aimed click does.
            onTap: () => kind == MusicGroupKind.artist
                ? controller.openArtist(group.name)
                : controller.openAlbum(group.name, artist),
          ),
        );
      },
    );
  }
}

/// The tiles.
///
/// The picture is the tile: an owner scanning for a record is scanning for a
/// sleeve they would recognise across a room, and a name under it is the
/// caption, not the subject.
class _GroupGrid extends ConsumerWidget {
  const _GroupGrid({
    required this.groups,
    required this.kind,
    required this.scroll,
  });

  final List<MusicGroup> groups;
  final MusicGroupKind kind;

  /// What scrolls the list, or `null` for its own.
  final ScrollController? scroll;

  /// How wide a tile may grow before the grid takes another column.
  static const double _extent = 200;

  /// The gap between two tiles, across and down.
  static const double spacing = AppSpacing.sm;

  /// How many tiles share a row at [width] — the count
  /// [SliverGridDelegateWithMaxCrossAxisExtent] arrives at for this grid.
  static int columnsFor(double width) =>
      math.max(1, (width / (_extent + spacing)).ceil());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = musicNavigatorOf(context, ref);

    return GridView.builder(
      controller: scroll,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _extent,
        // Taller than it is wide: the picture is square, and the caption and
        // its controls live in what is left.
        childAspectRatio: 3 / 4,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final artist = group.entries.first.albumArtist;

        return MusicGroupMenu(
          group: group,
          kind: kind,
          builder: (context, menu) => Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => kind == MusicGroupKind.artist
                  ? controller.openArtist(group.name)
                  : controller.openAlbum(group.name, artist),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      // Laid out by what the tile is given rather than by a fixed
                      // size: the grid's columns change with the width of the
                      // window, and a picture that ignored that would either
                      // overflow the narrow case or float in the wide one.
                      child: LayoutBuilder(
                        builder: (context, constraints) => _GroupArt(
                          group: group,
                          kind: kind,
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
                      musicGroupName(group, l10n, kind: kind),
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      kind == MusicGroupKind.album
                          ? artist ?? l10n.musicUnknownArtist
                          : l10n.musicTrackCount(group.entries.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The same controls the row carries, so choosing tiles costs
                  // the owner nothing they could do with rows.
                  Align(
                    alignment: Alignment.centerRight,
                    child: _GroupActions(group: group, kind: kind, menu: menu),
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

/// A group's picture: a record's sleeve, or a circle for an artist.
///
/// An artist's picture is one of their own records', because that is the only
/// picture this application has: nothing here fetches photographs, and a
/// generic silhouette against every name says an artist is an artist and
/// nothing about which one. The circle is what tells the two lists apart at a
/// glance.
class _GroupArt extends StatelessWidget {
  const _GroupArt({
    required this.group,
    required this.kind,
    required this.side,
  });

  final MusicGroup group;
  final MusicGroupKind kind;
  final double side;

  @override
  Widget build(BuildContext context) {
    final coverId = _coverOf(group);
    final art = AlbumArt(coverId: coverId, side: side);

    return kind == MusicGroupKind.artist ? ClipOval(child: art) : art;
  }

  /// The first picture any of the group's tracks carries.
  ///
  /// Not simply the first track's: a record whose opening track was ripped
  /// without its artwork would show a blank sleeve while eleven of its tracks
  /// carry one.
  static String? _coverOf(MusicGroup group) {
    for (final entry in group.entries) {
      final coverId = entry.metadata.coverId;
      if (coverId != null) return coverId;
    }

    return null;
  }
}

/// Play, and play in an order nobody chose.
///
/// On the row itself rather than only in a menu: playing a record is what an
/// owner came here to do, and a control they have to go looking for is one
/// they stop using.
class _GroupActions extends ConsumerWidget {
  const _GroupActions({
    required this.group,
    required this.kind,
    required this.menu,
  });

  final MusicGroup group;
  final MusicGroupKind kind;

  /// The menu the ⋮ button opens, owned by the [MusicGroupMenu] around the
  /// row.
  final MenuController menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (group.entries.isEmpty) return const SizedBox.shrink();
    final within = musicWithinOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: kind == MusicGroupKind.album
              ? l10n.audioPlayAlbum
              : l10n.audioPlayArtist,
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _play(ref, within, shuffled: false),
        ),
        IconButton(
          tooltip: kind == MusicGroupKind.album
              ? l10n.audioShuffleAlbum
              : l10n.audioShuffleArtist,
          icon: const Icon(Icons.shuffle),
          // The same gathering "play album" does, in a different order: the
          // queue is the record, or the artist's records in the part of the
          // library the nearest MusicScope browses — never the one track this
          // button happens to have in hand.
          onPressed: () => _play(ref, within, shuffled: true),
        ),
        // Autofill and the editor live in the menu: they are what an owner does
        // to a record now and then, not what they came here to do.
        IconButton(
          tooltip: l10n.musicGroupActions,
          icon: const Icon(Icons.more_vert),
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        ),
      ],
    );
  }

  /// Plays the group, gathered from [within] — the screen's part of the
  /// library, or the whole of it where [within] is `null`.
  void _play(
    WidgetRef ref,
    List<MusicEntry>? within, {
    required bool shuffled,
  }) {
    final player = ref.read(audioPlaybackControllerProvider.notifier);
    final first = group.entries.first.file;

    unawaited(
      kind == MusicGroupKind.album
          ? player.playAlbum(first, shuffled: shuffled, within: within)
          : player.playArtist(first, shuffled: shuffled, within: within),
    );
  }
}

/// An album's or an artist's own actions: autofill, adding to a playlist and
/// the tag editor.
///
/// Autofill on an album is UC-34's review of the one record; on an artist it
/// is a batch over all their songs, which the owner does not review record by
/// record.
///
/// Opened by right-click, long press, or the ⋮ button on the row. A long press
/// opens it here though it picks the song on a track's row: albums and artists
/// are not picked, so the gesture is free for their menu. The row is built
/// by [builder] and handed the [MenuController], so the button sits wherever
/// the row wants it.
class MusicGroupMenu extends ConsumerWidget {
  /// Creates the wrapper.
  const MusicGroupMenu({
    required this.group,
    required this.kind,
    required this.builder,
    super.key,
  });

  /// The album or artist the menu acts on.
  final MusicGroup group;

  /// Whether [group] is an artist or an album.
  final MusicGroupKind kind;

  /// The row, wired to open the menu through the controller it is given.
  final Widget Function(BuildContext context, MenuController menu) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.auto_fix_high_outlined),
          onPressed: () => unawaited(
            kind == MusicGroupKind.album
                ? startAutofill(
                    context,
                    ref,
                    _gathered(context, ref),
                    kind: AutofillKind.record,
                  )
                : startBatchAutofill(context, ref, _gathered(context, ref)),
          ),
          child: Text(l10n.autofillAction),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.playlist_add),
          onPressed: () => unawaited(
            startAddToPlaylist(context, ref, _gathered(context, ref)),
          ),
          child: Text(l10n.playlistAddTo),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => unawaited(
            startManyTagEdit(
              context,
              _gathered(context, ref),
              label: musicGroupName(group, l10n, kind: kind),
            ),
          ),
          child: Text(l10n.tagEditAction),
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

  /// Everything that belongs to [group], read when an item is pressed rather
  /// than when the row was built.
  ///
  /// A named album and an artist are gathered from the whole library, never
  /// from [MusicGroup.entries] alone: the group was cut by a screen that may
  /// not hold the whole of it — an artist inside a genre shows only their
  /// records listed under it — and an edit to "the album" or "the artist" that
  /// skipped the tracks the screen left out would leave it half-tagged.
  ///
  /// An untitled album is gathered from the part of the library the nearest
  /// [MusicScope] browses, as its play buttons are: a nameless group is not a
  /// record, so inside a genre it is only the artist's loose tracks of that
  /// genre, and the others have nothing to do with what the owner is looking
  /// at. Outside a scope that is the whole library too.
  ///
  /// [MusicGroup.entries] is only the answer while the library is not loaded.
  List<MusicEntry> _gathered(BuildContext context, WidgetRef ref) {
    final library = ref.read(musicLibraryControllerProvider).value?.entries;
    if (library == null || group.entries.isEmpty) return group.entries;

    final first = group.entries.first;
    if (kind == MusicGroupKind.artist) {
      return entriesOfArtist(first.albumArtist, library);
    }

    final from = first.album == null
        ? musicWithinOf(context) ?? library
        : library;

    return tracksOfAlbum(first.album, first.albumArtist, from);
  }
}

/// The tracks.
///
/// Also where several of them are picked: touch and hold a row, or Ctrl- or
/// Shift-click it, and the list is selecting — every row leads with a tick
/// box, a tap toggles a song rather than playing it, and a bar above the rows
/// says how many are picked. The selection itself lives in
/// [songSelectionProvider] rather than here, so that what Back does can ask
/// about it, and so that it outlasts the spinner a reload puts in the list's
/// place.
class MusicTrackList extends ConsumerStatefulWidget {
  /// Creates the list.
  const MusicTrackList({
    required this.entries,
    required this.numbered,
    required this.selectionScope,
    this.emptyMessage,
    this.indexed = false,
    super.key,
  });

  /// The tracks to show, already in the order they belong in.
  final List<MusicEntry> entries;

  /// Whether each row leads with its track number.
  ///
  /// True inside an album, where the number is what orders the record; false
  /// in Songs, where the list spans the library and a number belonging to some
  /// other record would say nothing.
  final bool numbered;

  /// Which list this is, compared with `==`: Songs, one record, a genre's
  /// songs, one search.
  ///
  /// A selection is made in, and shown by, the list of one identity alone.
  /// Named by the host rather than inferred from this widget: going from
  /// Songs into a record, or from one record to the next, redraws this same
  /// list with other tracks, and only the name says it is another list.
  final Object selectionScope;

  /// What to say when there is nothing to show, or `null` to show nothing.
  final String? emptyMessage;

  /// Whether a [LetterBar] stands beside the rows, filed by title.
  ///
  /// For Songs, which is the whole library in title order; not for a record,
  /// whose tracks are in the order they are played.
  final bool indexed;

  @override
  ConsumerState<MusicTrackList> createState() => _MusicTrackListState();
}

class _MusicTrackListState extends ConsumerState<MusicTrackList> {
  /// What Esc is heard through, and what is focused when a selection starts,
  /// so that Esc ends it without the owner first having to click somewhere.
  ///
  /// Out of the Tab order: it is focused for the keys it hears, and a Tab
  /// stop that shows nothing would only be one more press to get past.
  final FocusNode _focus = FocusNode(
    debugLabel: 'MusicTrackList',
    skipTraversal: true,
  );

  /// Whether a prune is already waiting for the end of the frame.
  bool _pruning = false;

  /// The selection's holder, kept from the start: a disposed list has no
  /// `ref` to reach it with, and leaving is when it is needed most.
  late final SongSelectionController _selection;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(songSelectionProvider.notifier)
      ..attach(widget.selectionScope);
  }

  @override
  void didUpdateWidget(MusicTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionScope == widget.selectionScope) return;

    // Another list drawn in this one's place: its own prune ends what was
    // picked in the last one.
    _selection
      ..detach(oldWidget.selectionScope)
      ..attach(widget.selectionScope);
  }

  @override
  void dispose() {
    final selection = _selection;
    final scope = widget.selectionScope;
    selection.detach(scope);
    // After the frame, when whatever replaces this list is on screen: the
    // same list drawn again keeps what was picked in it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => selection.endIfUnshown(scope),
    );

    _focus.dispose();
    super.dispose();
  }

  /// The tracks' paths, in the list's order.
  List<String> _order() => [
    for (final entry in widget.entries) entry.file.path,
  ];

  /// The performer to put under a row's title, or `null` for a row that names
  /// none.
  ///
  /// In Songs the performer is always shown: the list spans the library, and a
  /// title alone does not say whose track it is.
  ///
  /// Inside an album it is shown only where it differs from the record's own
  /// artist — which is what a compilation is: twelve performers under one album
  /// artist, and the whole point of grouping by the album artist is that their
  /// names are still worth reading. On an ordinary single-artist record the
  /// same name under all twelve rows would be noise, so it is left off — the
  /// record's own artist is named in the breadcrumb above the list on both
  /// paths into a record, so leaving it off a row does not take it off the
  /// screen.
  String? _performerOf(MusicEntry entry, AppLocalizations l10n) {
    if (!widget.numbered) return musicArtistOf(entry, l10n);

    final performer = entry.artist;

    return performer == null || performer == entry.albumArtist
        ? null
        : performer;
  }

  /// Keeps the selection to the songs this list shows, once the frame is
  /// drawn — a provider is not changed while widgets are being built.
  ///
  /// A selection made in another list ends here: this is what makes opening
  /// another record, or searching for something else, leave nothing picked.
  /// Within this list, the songs a rescan took away drop out of it, and a
  /// selection left with none ends.
  void _schedulePrune() {
    if (_pruning) return;
    _pruning = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruning = false;
      if (!mounted || !ref.read(songSelectionProvider).isActive) return;

      ref
          .read(songSelectionProvider.notifier)
          .retainIn(widget.selectionScope, _order());
    });
  }

  /// A tap or click on [entry]'s row.
  ///
  /// The keyboard is read now rather than tracked: what matters is whether
  /// Shift or Ctrl is down as the owner clicks.
  void _tap(MusicEntry entry, {required bool selecting}) {
    final keyboard = HardwareKeyboard.instance;
    final selection = ref.read(songSelectionProvider.notifier);
    final scope = widget.selectionScope;
    final path = entry.file.path;

    if (keyboard.isShiftPressed) {
      selection.rangeTo(scope, path, _order());
    } else if (keyboard.isControlPressed || selecting) {
      selection.toggle(scope, path);
    } else {
      _play(entry);
    }
  }

  /// The picked songs, in the list's order.
  List<MusicEntry> _pickedEntries() {
    final paths = ref.read(songSelectionProvider).paths;

    return [
      for (final entry in widget.entries)
        if (paths.contains(entry.file.path)) entry,
    ];
  }

  /// Asks which playlist the picked songs go to, in the list's order.
  ///
  /// The selection is kept: the owner may want the same songs in another
  /// playlist too.
  Future<void> _addSelected() =>
      startAddToPlaylist(context, ref, _pickedEntries());

  /// Autofills the picked songs: one as UC-34's lone track, several as a
  /// batch.
  ///
  /// The selection is kept, as after [_addSelected]: the owner may want to do
  /// more with the same songs.
  Future<void> _autofillSelected() =>
      startBatchAutofill(context, ref, _pickedEntries());

  /// Opens the tag form over the picked songs, in the list's order, and ends
  /// the selection if it wrote any of them.
  ///
  /// Not when it was cancelled, or wrote nothing: the owner may want to adjust
  /// what is picked and try again.
  Future<void> _editSelected() async {
    final picked = _pickedEntries();
    if (picked.isEmpty) return;

    final label = AppLocalizations.of(context).musicSelectionLabel;
    final written = await startManyTagEdit(context, picked, label: label);

    // Through the holder kept from the start rather than `ref`: the save
    // reloads the library, and the list may have been through the spinner and
    // be gone from the tree by the time the form has closed.
    if (written) _selection.clear();
  }

  /// Inside a record, a track plays the record from there; in Songs it plays
  /// alone, because there is no record around it to continue.
  void _play(MusicEntry entry) {
    final player = ref.read(audioPlaybackControllerProvider.notifier);

    unawaited(
      widget.numbered
          ? player.playAlbum(entry.file, within: musicWithinOf(context))
          : player.playTrack(entry.file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scope = widget.selectionScope;
    final entries = widget.entries;
    final selection = ref.watch(songSelectionProvider);
    final selecting = selection.isActiveIn(scope);

    // Taken from the search field, or wherever it was, when a selection
    // starts here: the owner has just clicked a row, and Esc should end what
    // they started.
    ref.listen(songSelectionProvider, (previous, next) {
      final started =
          next.isActiveIn(scope) && !(previous?.isActiveIn(scope) ?? false);
      if (started) _focus.requestFocus();
    });

    if (selection.isActive) _schedulePrune();

    if (entries.isEmpty && widget.emptyMessage != null) {
      return Center(
        child: Text(
          widget.emptyMessage!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final controller = ref.read(songSelectionProvider.notifier);
    // Counted against the rows rather than read off the selection: for the
    // one frame between a rescan and the prune, a song that has left the list
    // must not be counted in it.
    final picked = selecting
        ? entries
              .where((entry) => selection.paths.contains(entry.file.path))
              .length
        : 0;

    // The rows, scrolled by the letter bar's controller where there is one.
    Widget rows(ScrollController? scroll) => ListView.builder(
      controller: scroll,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final path = entry.file.path;
        final performer = _performerOf(entry, l10n);
        final title = musicTitleOf(entry, l10n);
        final isPicked = selecting && selection.paths.contains(path);

        return MusicRowMenu(
          entry: entry,
          // A right-click on a picked song is about the picked
          // songs; on any other it is about that song alone.
          selection: isPicked
              ? (count: picked, editTags: () => unawaited(_editSelected()))
              : null,
          selectionItems: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.playlist_add),
              onPressed: () => unawaited(_addSelected()),
              child: Text(l10n.playlistAddTo),
            ),
          ],
          child: SongTile(
            title: title,
            subtitle: performer,
            duration: entry.duration,
            picked: selecting ? isPicked : null,
            // Through the row's own logic, so Shift draws a range
            // from a tick box as it does from a row.
            onTicked: () => _tap(entry, selecting: selecting),
            leading: widget.numbered
                ? SizedBox(
                    width: AppSpacing.xl,
                    child: Text(
                      entry.metadata.track?.toString() ?? '',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : AlbumArt(coverId: entry.metadata.coverId, side: 44),
            onTap: () => _tap(entry, selecting: selecting),
            // Touch and hold picks songs; the song's own menu is on
            // its ⋮ button and a right-click.
            onLongPress: () => controller.toggle(scope, path),
          ),
        );
      },
    );

    return CallbackShortcuts(
      bindings: {
        if (selecting)
          const SingleActivator(LogicalKeyboardKey.escape): controller.clear,
      },
      child: Focus(
        focusNode: _focus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecting)
              SongSelectionBar(
                count: picked,
                allSelected: picked == entries.length,
                onStop: controller.clear,
                onSelectAll: () => controller.selectAll(scope, _order()),
                onEditTags: () => unawaited(_editSelected()),
                actions: [
                  IconButton(
                    tooltip: l10n.autofillAction,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    onPressed: () => unawaited(_autofillSelected()),
                  ),
                  IconButton(
                    tooltip: l10n.playlistAddTo,
                    icon: const Icon(Icons.playlist_add),
                    onPressed: () => unawaited(_addSelected()),
                  ),
                ],
              ),
            Expanded(
              // Keyed so the rows, and how far they are scrolled, survive the
              // bar arriving above them.
              key: const ValueKey('rows'),
              child: widget.indexed
                  ? LetterIndexedScroll(
                      names: [for (final entry in entries) entry.title],
                      builder: (context, scroll) => rows(scroll),
                    )
                  : rows(null),
            ),
          ],
        ),
      ),
    );
  }
}

/// One song's row: what leads it, its title, who plays it and how long it
/// is.
///
/// The look every song list shares, so that a row in a playlist reads as the
/// same row it is in Songs or inside a record. While a list is selecting
/// ([picked] is not `null`), the leading slot holds a tick box instead —
/// in place of the number or the cover rather than beside it, so a phone's
/// row does not lose title width.
class SongTile extends StatelessWidget {
  /// Creates the row.
  const SongTile({
    required this.title,
    required this.leading,
    required this.onTap,
    required this.onLongPress,
    this.subtitle,
    this.duration,
    this.picked,
    this.onTicked,
    this.greyed = false,
    super.key,
  });

  /// The song's title, already worded.
  final String title;

  /// What leads the row while the list is not selecting: a track number, or
  /// the cover.
  final Widget leading;

  /// The line under the title, or `null` for none.
  final String? subtitle;

  /// How long the song lasts, or `null` when that is not known.
  final Duration? duration;

  /// Whether the song is ticked while its list is selecting, or `null` while
  /// it is not.
  final bool? picked;

  /// What the tick box does.
  final VoidCallback? onTicked;

  /// Whether the row is drawn as one that cannot be played — a song a
  /// playlist names that the library no longer has. It still answers taps:
  /// it can be picked and removed.
  final bool greyed;

  /// A tap or a click on the row.
  final VoidCallback onTap;

  /// Touch and hold.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ticked = picked;
    final length = duration;
    final faded = greyed ? theme.disabledColor : null;

    return ListTile(
      selected: ticked ?? false,
      // Not `enabled: false`, which would also stop the row being picked.
      textColor: faded,
      leading: ticked != null
          ? Checkbox(
              value: ticked,
              semanticLabel: l10n.musicSelectionSelect(title),
              onChanged: (_) => onTicked?.call(),
            )
          : leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: length == null
          ? null
          : Text(
              formatPlaybackPosition(length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: faded ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// What is picked, and what can be done with it.
///
/// Above the rows, in the list's own area rather than in a host's header, so
/// it works in every place a song list is drawn.
class SongSelectionBar extends StatelessWidget {
  /// Creates the bar.
  const SongSelectionBar({
    required this.count,
    required this.allSelected,
    required this.onStop,
    required this.onSelectAll,
    required this.onEditTags,
    this.actions = const [],
    super.key,
  });

  /// How many of the list's songs are picked.
  final int count;

  /// Whether every song in the list is picked, when *Select all* would do
  /// nothing.
  final bool allSelected;

  /// Ends the selection.
  final VoidCallback onStop;

  /// Picks every song in the list.
  final VoidCallback onSelectAll;

  /// Opens the tag form over the picked songs, or `null` when none of them
  /// can be tagged.
  final VoidCallback? onEditTags;

  /// What else the list that draws the bar can do with the picked songs —
  /// icon buttons, set before *Edit tags…*.
  ///
  /// With any, *Edit tags…* is an icon too in a bar narrower than [roomy]:
  /// on a phone the words beside them would leave no room for the count.
  final List<Widget> actions;

  /// How wide a bar must be for *Edit tags…* to keep its words beside
  /// [actions] — wider than any phone held upright.
  static const double roomy = 480;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _bar);

  Widget _bar(BuildContext context, BoxConstraints constraints) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final compact = actions.isNotEmpty && constraints.maxWidth < roomy;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.musicSelectionStop,
            icon: const Icon(Icons.close),
            onPressed: onStop,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.musicSelectionCount(count),
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // An icon, and the action without the count: the count is already
          // in the row, and a phone has no width to spend on saying it twice.
          if (!allSelected)
            IconButton(
              tooltip: l10n.musicSelectionAll,
              icon: const Icon(Icons.select_all),
              onPressed: onSelectAll,
            ),
          ...actions,
          const SizedBox(width: AppSpacing.xs),
          // What is done with the picked songs goes here, last in the row.
          if (compact)
            IconButton(
              tooltip: l10n.tagEditAction,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditTags,
            )
          else
            FilledButton.tonal(
              onPressed: onEditTags,
              child: Text(l10n.tagEditAction),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// A track's own actions.
///
/// Right-click is what a desktop owner reaches for, and the button beside the
/// row is what makes the same actions reachable on a phone and from the
/// keyboard. Both open the one menu, so there is no second list of actions to
/// keep in step. Touch and hold is not one of them: on a song's row it picks
/// the song (see [MusicTrackList]).
///
/// The one exception is a right-click on a picked song while songs are being
/// picked: that opens a menu for the picked songs instead (see [selection]).
/// The ⋮ button never does, so a picked song's own actions stay reachable.
class MusicRowMenu extends ConsumerWidget {
  /// Creates the wrapper.
  const MusicRowMenu({
    required this.entry,
    required this.child,
    this.selection,
    this.extraItems = const [],
    this.selectionItems = const [],
    super.key,
  });

  /// The track the menu acts on.
  final MusicEntry entry;

  /// What a right-click offers when [entry] is one of the picked songs: how
  /// many are picked, and what pressing *Edit tags* does. `null` for a song
  /// that is not picked, whose right-click opens its own menu.
  final ({int count, VoidCallback editTags})? selection;

  /// The row itself.
  final Widget child;

  /// What the list the row is in adds to the song's own menu, after the
  /// items every song has.
  final List<Widget> extraItems;

  /// What the list the row is in adds to the picked songs' menu, before
  /// *Edit tags* — *Add to playlist…* among it.
  final List<Widget> selectionItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final within = musicWithinOf(context);
    final picked = selection;

    return SongRowMenu(
      ownItems: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.play_arrow),
          onPressed: () => _play(ref, (player) => player.playTrack(entry.file)),
          child: Text(l10n.audioPlay),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.album_outlined),
          onPressed: () => _play(
            ref,
            (player) => player.playAlbum(entry.file, within: within),
          ),
          child: Text(l10n.audioPlayAlbum),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline),
          onPressed: () => _play(
            ref,
            (player) => player.playArtist(entry.file, within: within),
          ),
          child: Text(l10n.audioPlayArtist),
        ),
        // The same two queues in an order nobody chose. Under the plays they
        // shuffle, so the pair reads as one decision — which record, then in
        // what order.
        MenuItemButton(
          leadingIcon: const Icon(Icons.shuffle),
          onPressed: () => _play(
            ref,
            (player) =>
                player.playAlbum(entry.file, shuffled: true, within: within),
          ),
          child: Text(l10n.audioShuffleAlbum),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.shuffle_on_outlined),
          onPressed: () => _play(
            ref,
            (player) =>
                player.playArtist(entry.file, shuffled: true, within: within),
          ),
          child: Text(l10n.audioShuffleArtist),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.auto_fix_high_outlined),
          onPressed: () => unawaited(
            startAutofill(context, ref, [entry], kind: AutofillKind.track),
          ),
          child: Text(l10n.autofillAction),
        ),
        // By hand, for what autofill could not find or found wrong.
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => unawaited(startTagEdit(context, entry)),
          child: Text(l10n.tagEditAction),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.playlist_add),
          onPressed: () => unawaited(startAddToPlaylist(context, ref, [entry])),
          child: Text(l10n.playlistAddTo),
        ),
        ...extraItems,
      ],
      selectionItems: picked == null
          ? null
          : [
              ...selectionItems,
              MenuItemButton(
                leadingIcon: const Icon(Icons.edit_outlined),
                onPressed: picked.editTags,
                child: Text(l10n.musicSelectionEditTags(picked.count)),
              ),
            ],
      child: child,
    );
  }

  void _play(
    WidgetRef ref,
    Future<void> Function(AudioPlaybackController player) play,
  ) => unawaited(play(ref.read(audioPlaybackControllerProvider.notifier)));
}

/// The menus of one song's row, whatever the row offers in them.
///
/// The one place step 3's rule for them lives. A right-click and the ⋮ button
/// beside the row open the row's own menu ([ownItems]). While the row is one
/// of the picked songs ([selectionItems] is not `null`), a right-click opens
/// the picked songs' menu instead; the ⋮ button never does, so the row's own
/// actions stay reachable. Touch and hold opens neither: on a song's row it
/// picks the song.
class SongRowMenu extends StatelessWidget {
  /// Creates the wrapper.
  const SongRowMenu({
    required this.ownItems,
    required this.child,
    this.selectionItems,
    super.key,
  });

  /// The row's own menu.
  final List<Widget> ownItems;

  /// The picked songs' menu when this row is one of them, or `null` for a
  /// row that is not picked.
  final List<Widget>? selectionItems;

  /// The row itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final picked = selectionItems;

    final own = MenuAnchor(
      menuChildren: ownItems,
      builder: (context, controller, _) {
        final row = Row(
          children: [
            Expanded(child: child),
            IconButton(
              tooltip: l10n.musicRowActions,
              icon: const Icon(Icons.more_vert),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ],
        );

        // The picked songs' menu answers the right-click instead, so this one
        // listens for none.
        return picked != null
            ? row
            : GestureDetector(
                onSecondaryTapDown: (details) =>
                    controller.open(position: details.localPosition),
                child: row,
              );
      },
    );

    if (picked == null) return own;

    return MenuAnchor(
      menuChildren: picked,
      builder: (context, controller, _) => GestureDetector(
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        child: own,
      ),
    );
  }
}
