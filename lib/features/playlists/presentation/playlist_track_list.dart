import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/music_entry.dart';
import '../../playback/application/song_selection_controller.dart';
import '../../playback/presentation/album_art.dart';
import '../../playback/presentation/music_display_name.dart';
import '../../playback/presentation/music_rows.dart';
import '../../tag_editor/presentation/edit_tags_launcher.dart';
import '../domain/playlist.dart';
import 'add_to_playlist.dart';

final Logger _log = Logger('playlists');

/// The songs of one playlist, in its order: played from, reordered, and
/// picked in.
///
/// The same rows and the same picking as every other song list (see
/// [MusicTrackList]), with what a playlist adds: a drag handle on each row,
/// rows for songs the library no longer has, and *Remove from playlist*.
///
/// What is picked is held by **entry id**, not by path, in the scope
/// `('playlist', <id>)`: the same song can be in a playlist twice, and
/// ticking one copy must tick that copy alone.
///
/// Drawn only once the library has loaded: [songs] is what says a row is
/// missing, and a library still being read would make every row look so.
class PlaylistTrackList extends ConsumerStatefulWidget {
  /// Creates the list.
  const PlaylistTrackList({
    required this.playlist,
    required this.songs,
    super.key,
  });

  /// The playlist whose songs these are.
  final Playlist playlist;

  /// The library's songs by file path: an entry whose path is not here is
  /// missing.
  final Map<String, MusicEntry> songs;

  @override
  ConsumerState<PlaylistTrackList> createState() => _PlaylistTrackListState();
}

class _PlaylistTrackListState extends ConsumerState<PlaylistTrackList> {
  /// What Esc is heard through, as in [MusicTrackList].
  final FocusNode _focus = FocusNode(
    debugLabel: 'PlaylistTrackList',
    skipTraversal: true,
  );

  /// Whether a prune is already waiting for the end of the frame.
  bool _pruning = false;

  /// The selection's holder, kept from the start: a disposed list has no
  /// `ref` to reach it with.
  late final SongSelectionController _selection;

  /// The order the owner dropped a row into, shown until the playlist that
  /// was stored with it arrives.
  ///
  /// Without it the row would spring back to where it was for as long as
  /// the write took, and then jump to where it was put.
  List<PlaylistEntry>? _moved;

  /// The name this list's selection is made under.
  Object get _scope => scopeOf(widget.playlist);

  /// The name a playlist's song list picks songs under.
  static Object scopeOf(Playlist playlist) => ('playlist', playlist.id);

  List<PlaylistEntry> get _entries => _moved ?? widget.playlist.entries;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(songSelectionProvider.notifier)..attach(_scope);
  }

  @override
  void didUpdateWidget(PlaylistTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored playlist has caught up with the drop, or something else
    // changed it: either way it is what to show now.
    if (!identical(oldWidget.playlist, widget.playlist)) _moved = null;

    final before = scopeOf(oldWidget.playlist);
    if (before == _scope) return;

    // Another playlist drawn in this one's place: its own prune ends what
    // was picked in the last one.
    _selection
      ..detach(before)
      ..attach(_scope);
  }

  @override
  void dispose() {
    final selection = _selection;
    final scope = _scope;
    selection.detach(scope);
    // After the frame, when whatever replaces this list is on screen: the
    // same list drawn again — after the library's spinner — keeps what was
    // picked in it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => selection.endIfUnshown(scope),
    );

    _focus.dispose();
    super.dispose();
  }

  /// The entries' ids, in the playlist's order.
  List<String> _order() => [for (final entry in _entries) entry.id];

  /// The library's song at [entry]'s place, or `null` when it is missing.
  MusicEntry? _songOf(PlaylistEntry entry) => widget.songs[entry.path];

  /// The ticked entries, in the playlist's order.
  List<PlaylistEntry> _ticked(Set<String> ids) => [
    for (final entry in _entries)
      if (ids.contains(entry.id)) entry,
  ];

  /// The library's songs among the ticked entries, each once, in the
  /// playlist's order — what *Edit tags…* (and *Add to playlist…*) act on.
  List<MusicEntry> _tickedSongs(Set<String> ids) {
    final seen = <String>{};

    return [
      for (final entry in _ticked(ids))
        if (_songOf(entry) case final song? when seen.add(song.file.path)) song,
    ];
  }

  /// Keeps the selection to the entries this list shows, once the frame is
  /// drawn, as [MusicTrackList] does.
  void _schedulePrune() {
    if (_pruning) return;
    _pruning = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruning = false;
      if (!mounted || !ref.read(songSelectionProvider).isActive) return;

      ref.read(songSelectionProvider.notifier).retainIn(_scope, _order());
    });
  }

  /// A tap or click on the row at [index].
  void _tap(int index, {required bool selecting}) {
    final keyboard = HardwareKeyboard.instance;
    final selection = ref.read(songSelectionProvider.notifier);
    final id = _entries[index].id;

    if (keyboard.isShiftPressed) {
      selection.rangeTo(_scope, id, _order());
    } else if (keyboard.isControlPressed || selecting) {
      selection.toggle(_scope, id);
    } else {
      _playFrom(index);
    }
  }

  /// Plays the playlist from the entry at [index] on, leaving out what the
  /// library no longer has. A missing entry itself plays nothing: it was
  /// what the owner asked for, and it cannot be had.
  void _playFrom(int index) {
    final entries = _entries;
    if (_songOf(entries[index]) == null) return;

    unawaited(
      ref
          .read(audioPlaybackControllerProvider.notifier)
          .playAll(
            name: widget.playlist.name,
            tracks: [
              for (final entry in entries.skip(index))
                if (_songOf(entry) case final song?) song.file,
            ],
          ),
    );
  }

  /// Takes the entries [ids] out of the playlist, and answers whether that
  /// was saved — said in a snackbar when it was not.
  Future<bool> _remove(Set<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).playlistSaveFailed;

    try {
      await ref
          .read(playlistsControllerProvider.notifier)
          .remove(widget.playlist.id, ids);

      return true;
    } on Object catch (error) {
      _log.warning('Could not remove from ${widget.playlist.id}: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));

      return false;
    }
  }

  /// Takes exactly the ticked entries out, and ends the selection once that
  /// is saved. Kept when it was not, so the owner can try again.
  Future<void> _removeTicked() async {
    final ids = {
      for (final entry in _ticked(ref.read(songSelectionProvider).paths))
        entry.id,
    };
    if (ids.isEmpty) return;

    if (await _remove(ids)) _selection.clear();
  }

  /// Opens the tag form over the ticked songs, and ends the selection if it
  /// wrote any of them — as [MusicTrackList] does.
  Future<void> _editTicked() async {
    final songs = _tickedSongs(ref.read(songSelectionProvider).paths);
    if (songs.isEmpty) return;

    final label = AppLocalizations.of(context).musicSelectionLabel;
    final written = await startManyTagEdit(context, songs, label: label);

    if (written) _selection.clear();
  }

  /// Asks which playlist the ticked songs go to: the library's, each once, in
  /// this playlist's order. The selection is kept, as in [MusicTrackList].
  Future<void> _addTicked() => startAddToPlaylist(
    context,
    ref,
    _tickedSongs(ref.read(songSelectionProvider).paths),
  );

  /// A row dropped by its handle at [to], the place it now holds: shown
  /// there at once, and stored.
  void _reorder(int from, int to) {
    if (from == to) return;
    // The playlist's rule is the older one, which counts [to] before the
    // row is taken out: one further on when it moves down the list.
    final before = from < to ? to + 1 : to;
    final playlist = widget.playlist;
    // The order on screen, which is a drop ahead of the stored one when the
    // last was not yet saved, moved by the playlist's own rule.
    final shown = Playlist(
      id: playlist.id,
      name: playlist.name,
      entries: _entries,
      createdAt: playlist.createdAt,
      modifiedAt: playlist.modifiedAt,
    );
    setState(
      () => _moved = shown.moving(from, before, playlist.modifiedAt).entries,
    );

    unawaited(_store(from, before));
  }

  Future<void> _store(int from, int to) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).playlistSaveFailed;

    try {
      await ref
          .read(playlistsControllerProvider.notifier)
          .move(widget.playlist.id, from, to);
    } on Object catch (error) {
      _log.warning('Could not reorder ${widget.playlist.id}: $error');
      // Back to the order that is stored.
      if (mounted) setState(() => _moved = null);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scope = _scope;
    final entries = _entries;
    final selection = ref.watch(songSelectionProvider);
    final selecting = selection.isActiveIn(scope);

    ref.listen(songSelectionProvider, (previous, next) {
      final started =
          next.isActiveIn(scope) && !(previous?.isActiveIn(scope) ?? false);
      if (started) _focus.requestFocus();
    });

    if (selection.isActive) _schedulePrune();

    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.playlistNoSongs,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final controller = ref.read(songSelectionProvider.notifier);
    // Counted against the rows, as [MusicTrackList] counts: an entry removed
    // a frame ago must not be counted.
    final ticked = selecting ? _ticked(selection.paths) : <PlaylistEntry>[];
    final tickedSongs = selecting
        ? _tickedSongs(selection.paths)
        : <MusicEntry>[];

    // What the picked songs' right-click menu offers besides *Edit tags*.
    List<Widget> selectionItems() => [
      MenuItemButton(
        leadingIcon: const Icon(Icons.playlist_remove),
        onPressed: () => unawaited(_removeTicked()),
        child: Text(l10n.playlistRemoveFrom),
      ),
      // Only songs the library has can be added: a missing one has no tags
      // to snapshot.
      if (tickedSongs.isNotEmpty)
        MenuItemButton(
          leadingIcon: const Icon(Icons.playlist_add),
          onPressed: () => unawaited(_addTicked()),
          child: Text(l10n.playlistAddTo),
        ),
    ];

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
                count: ticked.length,
                allSelected: ticked.length == entries.length,
                onStop: controller.clear,
                onSelectAll: () => controller.selectAll(scope, _order()),
                // Only songs the library has can be tagged: a missing one has
                // no file to write.
                onEditTags: tickedSongs.isEmpty
                    ? null
                    : () => unawaited(_editTicked()),
                actions: [
                  IconButton(
                    tooltip: l10n.playlistRemoveFrom,
                    icon: const Icon(Icons.playlist_remove),
                    onPressed: () => unawaited(_removeTicked()),
                  ),
                  IconButton(
                    tooltip: l10n.playlistAddTo,
                    icon: const Icon(Icons.playlist_add),
                    onPressed: tickedSongs.isEmpty
                        ? null
                        : () => unawaited(_addTicked()),
                  ),
                ],
              ),
            Expanded(
              key: const ValueKey('rows'),
              child: ReorderableListView.builder(
                // The handle is the only thing a row is dragged by: touch and
                // hold picks songs here, as in every song list.
                buildDefaultDragHandles: false,
                itemCount: entries.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final song = _songOf(entry);
                  final isPicked =
                      selecting && selection.paths.contains(entry.id);

                  final tile = SongTile(
                    title: song != null
                        ? musicTitleOf(song, l10n)
                        : tagOr(entry.title, l10n.musicUnknownTitle),
                    subtitle: song != null
                        ? musicArtistOf(song, l10n)
                        : _missingLine(entry, l10n),
                    duration: song?.duration ?? entry.duration,
                    picked: selecting ? isPicked : null,
                    onTicked: () => _tap(index, selecting: selecting),
                    greyed: song == null,
                    leading: AlbumArt(
                      coverId: song?.metadata.coverId,
                      side: 44,
                    ),
                    onTap: () => _tap(index, selecting: selecting),
                    onLongPress: () => controller.toggle(scope, entry.id),
                  );

                  final removeThis = MenuItemButton(
                    leadingIcon: const Icon(Icons.playlist_remove),
                    onPressed: () => unawaited(_remove({entry.id})),
                    child: Text(l10n.playlistRemoveFrom),
                  );

                  final menu = song != null
                      ? MusicRowMenu(
                          entry: song,
                          selection: isPicked
                              ? (
                                  count: tickedSongs.length,
                                  editTags: () => unawaited(_editTicked()),
                                )
                              : null,
                          extraItems: [removeThis],
                          selectionItems: selectionItems(),
                          child: tile,
                        )
                      // A missing song has nothing to play or to tag: only
                      // its place in the playlist, to remove.
                      : SongRowMenu(
                          ownItems: [removeThis],
                          selectionItems: isPicked
                              ? [
                                  ...selectionItems(),
                                  if (tickedSongs.isNotEmpty)
                                    MenuItemButton(
                                      leadingIcon: const Icon(
                                        Icons.edit_outlined,
                                      ),
                                      onPressed: () => unawaited(_editTicked()),
                                      child: Text(
                                        l10n.musicSelectionEditTags(
                                          tickedSongs.length,
                                        ),
                                      ),
                                    ),
                                ]
                              : null,
                          child: tile,
                        );

                  return Row(
                    // By entry id: the same song twice is two rows, and each
                    // must keep its own place as they move.
                    key: ValueKey(entry.id),
                    children: [
                      Expanded(child: menu),
                      // Always drawn, and still while picking — but not
                      // dragged then: two gestures on one row at once is
                      // a bug farm.
                      ReorderableDragStartListener(
                        index: index,
                        enabled: !selecting,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Icon(
                            Icons.drag_handle,
                            semanticLabel: l10n.playlistReorder,
                            color: selecting
                                ? theme.disabledColor
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The line under a missing song's title: that it is missing, and whose
  /// it was when it was added.
  static String _missingLine(PlaylistEntry entry, AppLocalizations l10n) {
    final artist = trimmedOrNull(entry.artist);

    return artist == null
        ? l10n.playlistMissing
        : l10n.playlistMissingBy(artist);
  }
}
