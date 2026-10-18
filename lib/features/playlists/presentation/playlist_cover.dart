import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../playback/presentation/album_art.dart';
import '../domain/playlist.dart';
import '../domain/playlist_mosaic.dart';

/// A playlist's picture: the one the owner chose, or a mosaic of its records.
///
/// The owner's own picture where there is one. Otherwise the sleeves of the
/// first four records among its songs in a two-by-two grid, one record's
/// sleeve alone, or a placeholder for a playlist with nothing to draw — see
/// [mosaicCoverIds] for which records count.
///
/// Its own widget rather than a mode of [AlbumArt]: that one is a record's
/// sleeve from the library's cover store, and this is drawn from two stores
/// and the catalog besides.
class PlaylistCover extends ConsumerStatefulWidget {
  /// Creates the picture of [playlist], [side] wide and tall.
  const PlaylistCover({
    required this.playlist,
    required this.side,
    this.radius,
    super.key,
  });

  /// Whose picture this is.
  final Playlist playlist;

  /// How wide and tall the square is.
  final double side;

  /// The corner radius, defaulting to one proportional to [side], as
  /// [AlbumArt]'s does.
  final double? radius;

  @override
  ConsumerState<PlaylistCover> createState() => _PlaylistCoverState();
}

class _PlaylistCoverState extends ConsumerState<PlaylistCover> {
  /// The owner's picture as last read, and whose it was.
  ///
  /// Every change to a playlist reads its picture again (see
  /// [playlistCoverProvider]), and without this the cover would blink to the
  /// mosaic and back each time a song was added or moved.
  Uint8List? _picture;
  String? _pictureOf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playlist = widget.playlist;
    final side = widget.side;
    // A picture taken off is forgotten, so one chosen later is never stood in
    // for by the one before it.
    if (playlist.coverId == null) _pictureOf = null;

    return Semantics(
      label: l10n.playlistCoverLabel,
      image: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius ?? side * 0.08),
          child: SizedBox.square(
            dimension: side,
            child: playlist.coverId == null
                ? _Mosaic(playlist: playlist, side: side)
                : _custom(playlist),
          ),
        ),
      ),
    );
  }

  /// The owner's picture, or the mosaic when it cannot be had.
  Widget _custom(Playlist playlist) {
    final read = ref.watch(
      playlistCoverProvider((id: playlist.id, modifiedAt: playlist.modifiedAt)),
    );
    switch (read) {
      case AsyncData(:final value):
        _picture = value;
        _pictureOf = playlist.id;
      case AsyncError():
        _picture = null;
        _pictureOf = playlist.id;
      case AsyncLoading():
        // A first read: a blank square for the moment it takes, rather than a
        // mosaic that is replaced as soon as it is seen.
        if (_pictureOf != playlist.id) return const _Blank();
    }

    final picture = _picture;
    if (picture == null) {
      return _Mosaic(playlist: playlist, side: widget.side);
    }

    return Image.memory(
      picture,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // A file that is there but does not decode is as good as none.
      errorBuilder: (context, _, _) =>
          _Mosaic(playlist: playlist, side: widget.side),
    );
  }
}

/// The sleeves of the playlist's first records, or the placeholder.
class _Mosaic extends ConsumerWidget {
  const _Mosaic({required this.playlist, required this.side});

  final Playlist playlist;
  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog =
        ref.watch(musicLibraryControllerProvider).value?.byPath ?? const {};
    final covers = mosaicCoverIds(playlist, catalog);

    if (covers.isEmpty) return _Placeholder(side: side);
    if (covers.length == 1) {
      return AlbumArt(coverId: covers.single, side: side, radius: 0);
    }

    // Two or three records leave a cell or two blank rather than repeating a
    // sleeve: a record shown twice reads as two records.
    final half = side / 2;
    Widget cell(int index) => index < covers.length
        ? AlbumArt(coverId: covers[index], side: half, radius: 0)
        : SizedBox.square(dimension: half, child: const _Blank());

    return Column(
      children: [
        Row(children: [cell(0), cell(1)]),
        Row(children: [cell(2), cell(3)]),
      ],
    );
  }
}

/// What a playlist with nothing to draw shows.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.playlist_play,
          size: side * 0.42,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// An empty square of the placeholder's colour.
class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
}
