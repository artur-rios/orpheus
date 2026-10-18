import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../autofill/application/autofill_controller.dart';
import '../../autofill/presentation/autofill_launcher.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../tag_editor/presentation/edit_tags_launcher.dart';
import '../application/audio_playback_controller.dart';
import '../domain/music_layout.dart';
import 'album_art.dart';
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
    super.key,
  });

  /// What to show.
  final List<MusicGroup> groups;

  /// Whether these are artists or albums.
  final MusicGroupKind kind;

  /// Rows or tiles.
  final MusicLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (layout) {
    MusicLayout.grid => _GroupGrid(groups: groups, kind: kind),
    MusicLayout.list => _GroupRows(groups: groups, kind: kind),
  };
}

/// The rows.
///
/// A builder rather than a column: scrolling cost must not grow with the size
/// of the library, and that applies to a list of albums exactly as it applies
/// to a list of tracks.
class _GroupRows extends ConsumerWidget {
  const _GroupRows({required this.groups, required this.kind});

  final List<MusicGroup> groups;
  final MusicGroupKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = musicNavigatorOf(context, ref);

    return ListView.builder(
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
            title: Text(musicGroupName(group, l10n, kind: kind)),
            subtitle: Text(
              kind == MusicGroupKind.album
                  ? artist ?? l10n.musicUnknownArtist
                  : l10n.musicTrackCount(group.entries.length),
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
  const _GroupGrid({required this.groups, required this.kind});

  final List<MusicGroup> groups;
  final MusicGroupKind kind;

  /// How wide a tile may grow before the grid takes another column.
  static const double _extent = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = musicNavigatorOf(context, ref);

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _extent,
        // Taller than it is wide: the picture is square, and the caption and
        // its controls live in what is left.
        childAspectRatio: 3 / 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
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

    return kind == MusicGroupKind.artist
        ? ClipOval(child: art)
        : art;
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

/// An album's or an artist's own actions: autofill (albums only) and the tag
/// editor.
///
/// Opened as a track's menu is — right-click, long press, or the ⋮ button on
/// the row — so the same gestures work on every kind of row. The row is built
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
        if (kind == MusicGroupKind.album)
          MenuItemButton(
            leadingIcon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: () => unawaited(
              startAutofill(
                context,
                ref,
                _gathered(ref),
                kind: AutofillKind.record,
              ),
            ),
            child: Text(l10n.autofillAction),
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => unawaited(
            startManyTagEdit(
              context,
              _gathered(ref),
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

  /// Everything in the library that belongs to [group], read when an item is
  /// pressed rather than when the row was built.
  ///
  /// From the whole library, never from [MusicGroup.entries] alone: the group
  /// was cut by a screen that may not hold the whole record, and an edit to
  /// "the album" that skipped the tracks the screen left out would leave it
  /// half-tagged. [MusicGroup.entries] is only the answer while the library is
  /// not loaded.
  List<MusicEntry> _gathered(WidgetRef ref) {
    final library = ref.read(musicLibraryControllerProvider).value?.entries;
    if (library == null || group.entries.isEmpty) return group.entries;

    final first = group.entries.first;

    return kind == MusicGroupKind.album
        ? tracksOfAlbum(first.album, first.albumArtist, library)
        : entriesOfArtist(first.albumArtist, library);
  }
}

/// The tracks.
class MusicTrackList extends ConsumerWidget {
  /// Creates the list.
  const MusicTrackList({
    required this.entries,
    required this.numbered,
    this.emptyMessage,
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

  /// What to say when there is nothing to show, or `null` to show nothing.
  final String? emptyMessage;

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
    if (!numbered) return musicArtistOf(entry, l10n);

    final performer = entry.artist;

    return performer == null || performer == entry.albumArtist
        ? null
        : performer;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final within = musicWithinOf(context);

    if (entries.isEmpty && emptyMessage != null) {
      return Center(
        child: Text(
          emptyMessage!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final performer = _performerOf(entry, l10n);
        final duration = entry.duration;

        return MusicRowMenu(
          entry: entry,
          child: ListTile(
            leading: numbered
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
            title: Text(
              musicTitleOf(entry, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: performer == null
                ? null
                : Text(performer, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: duration == null
                ? null
                : Text(
                    formatPlaybackPosition(duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
            // Inside a record, a track plays the record from there; in Songs
            // it plays alone, because there is no record around it to
            // continue.
            onTap: () {
              final player = ref.read(audioPlaybackControllerProvider.notifier);

              unawaited(
                numbered
                    ? player.playAlbum(entry.file, within: within)
                    : player.playTrack(entry.file),
              );
            },
          ),
        );
      },
    );
  }
}

/// A track's own actions.
///
/// Right-click is what a desktop owner reaches for; a long press is the same
/// gesture on a phone; and the button beside the row is what makes the same
/// actions reachable from the keyboard. All three open the one menu, so there
/// is no second list of actions to keep in step.
class MusicRowMenu extends ConsumerWidget {
  /// Creates the wrapper.
  const MusicRowMenu({required this.entry, required this.child, super.key});

  /// The track the menu acts on.
  final MusicEntry entry;

  /// The row itself.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final within = musicWithinOf(context);

    return MenuAnchor(
      menuChildren: [
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
      ],
      builder: (context, controller, _) => GestureDetector(
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        onLongPressStart: (details) =>
            controller.open(position: details.localPosition),
        child: Row(
          children: [
            Expanded(child: child),
            IconButton(
              tooltip: l10n.musicRowActions,
              icon: const Icon(Icons.more_vert),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ],
        ),
      ),
    );
  }

  void _play(
    WidgetRef ref,
    Future<void> Function(AudioPlaybackController player) play,
  ) => unawaited(play(ref.read(audioPlaybackControllerProvider.notifier)));
}
