import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../data_export/domain/backup.dart';
import '../../shell/presentation/confirmation_dialog.dart';
import '../../tag_editor/domain/tag_edits.dart';
import '../domain/auto_playlists.dart';
import '../domain/playlist.dart';
import 'add_to_playlist.dart';
import 'playlist_name_dialog.dart';

final Logger _log = Logger('playlists');

/// A playlist's own actions: rename, its cover, export and delete.
///
/// An auto playlist's are only *Add to playlist…* — every song of it, into
/// one of the owner's — and export: it is Orpheus's to keep, not the owner's
/// to rename, re-cover or delete. Given the playlist as it is shown, named
/// (see `shownAs`), since that name is what an export is called.
///
/// Opened by right-click, touch and hold, or the ⋮ button, as an album's menu
/// is: a playlist is a row like an album, not a song in a list, so touch and
/// hold is free to open its menu rather than start a selection. The row is
/// built by [builder] and handed the [MenuController], so the button sits
/// wherever the row wants it.
class PlaylistMenu extends ConsumerWidget {
  /// Creates the wrapper.
  const PlaylistMenu({
    required this.playlist,
    required this.builder,
    super.key,
  });

  /// The playlist the menu acts on.
  final Playlist playlist;

  /// The row, wired to open the menu through the controller it is given.
  final Widget Function(BuildContext context, MenuController menu) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final export = MenuItemButton(
      leadingIcon: const Icon(Icons.file_download_outlined),
      onPressed: () => unawaited(_export(context, ref)),
      child: Text(l10n.playlistExport),
    );

    return MenuAnchor(
      menuChildren: isAutoPlaylistId(playlist.id)
          ? [
              MenuItemButton(
                leadingIcon: const Icon(Icons.playlist_add),
                onPressed: () => unawaited(_addAll(context, ref)),
                child: Text(l10n.playlistAddTo),
              ),
              export,
            ]
          : _ownersItems(context, ref, l10n, export),
      builder: (context, controller, _) => GestureDetector(
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        onLongPressStart: (details) =>
            controller.open(position: details.localPosition),
        child: builder(context, controller),
      ),
    );
  }

  /// What one of the owner's own playlists offers.
  List<Widget> _ownersItems(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Widget export,
  ) => [
    MenuItemButton(
      leadingIcon: const Icon(Icons.drive_file_rename_outline),
      onPressed: () => unawaited(_rename(context, ref)),
      child: Text(l10n.playlistRename),
    ),
    MenuItemButton(
      leadingIcon: const Icon(Icons.image_outlined),
      onPressed: () => unawaited(_chooseCover(context, ref)),
      child: Text(l10n.playlistChooseCover),
    ),
    // Only where there is a cover of the owner's own to take off: the
    // mosaic is what a playlist has when it has none.
    if (playlist.coverId != null)
      MenuItemButton(
        leadingIcon: const Icon(Icons.hide_image_outlined),
        onPressed: () => unawaited(_removeCover(context, ref)),
        child: Text(l10n.playlistRemoveCover),
      ),
    export,
    MenuItemButton(
      leadingIcon: const Icon(Icons.delete_outline),
      onPressed: () => unawaited(_delete(context, ref)),
      child: Text(l10n.playlistDelete),
    ),
  ];

  // Each action takes what it needs from the tree before its first wait: the
  // row it was opened from may be gone by the time the owner answers — moved
  // by the change itself, which reorders the list, or deleted.

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final playlists = ref.read(playlistsControllerProvider.notifier);

    final name = await PlaylistNameDialog.ask(
      context,
      title: l10n.playlistRenameTitle,
      confirmLabel: l10n.playlistRenameConfirm,
      initialName: playlist.name,
    );
    if (name == null || name == playlist.name) return;

    await _saving(messenger, l10n, () => playlists.rename(playlist.id, name));
  }

  Future<void> _chooseCover(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final playlists = ref.read(playlistsControllerProvider.notifier);

    final bytes = await ref.read(coverPickerProvider).pickImage();
    if (bytes == null) return;
    // The same two formats the tag editor takes, for the same reason: a
    // picture every reader can draw.
    if (!isSupportedCover(bytes)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.playlistCoverNotImage)),
      );

      return;
    }
    // A picture a backup would not read back: refused here, so that Orpheus
    // never makes a backup it cannot restore in full.
    if (bytes.length > maxBackupCoverBytes) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.playlistCoverTooLarge)),
      );

      return;
    }

    await _saving(
      messenger,
      l10n,
      () => playlists.setCover(playlist.id, bytes),
    );
  }

  Future<void> _removeCover(BuildContext context, WidgetRef ref) => _saving(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
    () =>
        ref.read(playlistsControllerProvider.notifier).removeCover(playlist.id),
  );

  /// Every song of the playlist the library has, into a playlist the owner
  /// chooses — an auto playlist copied into one of their own.
  Future<void> _addAll(BuildContext context, WidgetRef ref) {
    final songs =
        ref.read(musicLibraryControllerProvider).value?.byPath ?? const {};

    return startAddToPlaylist(context, ref, [
      for (final entry in playlist.entries) ?songs[entry.path],
    ]);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final playlists = ref.read(playlistsControllerProvider.notifier);

    try {
      final saved = await playlists.exportM3u(playlist);
      // A cancelled dialog is the owner's answer, not something to report.
      if (saved == null) return;

      // Where it went when that is a path; on Android it is a document
      // provider's address, and only that it was exported is worth saying.
      final path = saved.path;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            path == null
                ? l10n.playlistExported
                : l10n.playlistExportSaved(path),
          ),
        ),
      );
    } on Object catch (error) {
      _log.warning('Could not export ${playlist.id}: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.playlistExportFailed(playlist.name))),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final playlists = ref.read(playlistsControllerProvider.notifier);

    final confirmed = await ConfirmationDialog.ask(
      context,
      title: l10n.playlistDeleteTitle(playlist.name),
      body: l10n.playlistDeleteBody,
      confirmLabel: l10n.playlistDeleteConfirm,
    );
    if (!confirmed) return;

    // Left open if it was: the tab reads an open playlist that is no longer
    // there as the list of them.
    await _saving(messenger, l10n, () => playlists.delete(playlist.id));
  }
}

/// Runs [change], and says so when it could not be saved.
///
/// The controller leaves the playlists as they were when a write fails, so
/// the sentence is the whole of what the owner needs to know.
Future<void> _saving(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Future<void> Function() change,
) async {
  try {
    await change();
  } on Object catch (error) {
    _log.warning('Could not change the playlists: $error');
    messenger.showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));
  }
}

/// Asks for a name and makes a playlist of it: the one way a playlist is
/// made, from the tab and (later) from *Add to playlist…*.
///
/// Answers the new playlist, or `null` when the owner cancelled or it could
/// not be saved — which has then been said.
Future<Playlist?> startNewPlaylist(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final playlists = ref.read(playlistsControllerProvider.notifier);

  final name = await PlaylistNameDialog.ask(
    context,
    title: l10n.playlistNew,
    confirmLabel: l10n.playlistCreate,
  );
  if (name == null) return null;

  try {
    return await playlists.create(name);
  } on Object catch (error) {
    _log.warning('Could not create a playlist: $error');
    messenger.showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));

    return null;
  }
}
