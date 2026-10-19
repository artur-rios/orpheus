import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../library/domain/music_entry.dart';
import '../domain/playlist.dart';
import 'playlist_menu.dart';

final Logger _log = Logger('playlists');

/// Adds [songs] to a playlist the owner chooses, at its end and in the order
/// given.
///
/// The one way songs get into a playlist, whatever they came from: a song, a
/// selection, an album or an artist. The owner picks the playlist — or has a
/// new one made — and, when some of the songs are in it already, says
/// whether to add those again. Then the count actually added is said. No
/// songs, nothing.
Future<void> startAddToPlaylist(
  BuildContext context,
  WidgetRef ref,
  List<MusicEntry> songs,
) async {
  if (songs.isEmpty) return;

  // Taken before the first wait: the row this was started from may be gone
  // by the time the owner has answered.
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final playlists = ref.read(playlistsControllerProvider.notifier);

  final choice = await showDialog<_Choice>(
    context: context,
    builder: (context) => const _PlaylistPicker(),
  );
  if (choice == null || !context.mounted) return;

  final chosen = choice.playlist ?? await startNewPlaylist(context, ref);
  if (chosen == null || !context.mounted) return;

  // As it is now, not as the picker listed it: it may have changed while the
  // owner was choosing.
  final current = _current(ref, chosen);
  final present = current.pathsIn();
  var skipDuplicates = false;
  if (songs.any((song) => present.contains(song.file.path))) {
    final answer = await showDialog<_Duplicates>(
      context: context,
      builder: (context) => _DuplicatesDialog(name: current.name),
    );
    if (answer == null) return;

    skipDuplicates = answer == _Duplicates.skip;
  }

  try {
    final added = await playlists.add(
      chosen.id,
      songs,
      skipDuplicates: skipDuplicates,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? l10n.playlistNothingAdded
              : l10n.playlistAdded(added, current.name),
        ),
      ),
    );
  } on Object catch (error) {
    _log.warning('Could not add to ${chosen.id}: $error');
    messenger.showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));
  }
}

/// [playlist] as the controller holds it now, or as it was given when it is
/// no longer there.
Playlist _current(WidgetRef ref, Playlist playlist) {
  for (final candidate
      in ref.read(playlistsControllerProvider).value ?? const <Playlist>[]) {
    if (candidate.id == playlist.id) return candidate;
  }

  return playlist;
}

/// What the picker answered: a playlist, or `null` for *New playlist…*.
class _Choice {
  const _Choice(this.playlist);

  final Playlist? playlist;
}

/// Whether the songs already in the playlist are added again.
enum _Duplicates { again, skip }

/// The dialog that lists the playlists, most recently changed first, with
/// *New playlist…* ahead of them.
///
/// Watches the playlists rather than being given them, so a list still being
/// read when the dialog opens fills in when it arrives.
class _PlaylistPicker extends ConsumerWidget {
  const _PlaylistPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = mostRecentFirst(
      ref.watch(playlistsControllerProvider).value ?? const <Playlist>[],
    );

    return AlertDialog(
      title: Text(l10n.playlistAddToTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.playlistAddToNew),
              onTap: () => Navigator.of(context).pop(const _Choice(null)),
            ),
            for (final playlist in all)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(l10n.playlistSongCount(playlist.entries.length)),
                onTap: () => Navigator.of(context).pop(_Choice(playlist)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// *Already in Road trip — add again?*, for the playlist named so.
class _DuplicatesDialog extends StatelessWidget {
  const _DuplicatesDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.playlistDuplicateTitle(name)),
      actions: [
        TextButton(
          // Focused, as in the confirmation dialog: a return pressed without
          // reading changes nothing.
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Duplicates.skip),
          child: Text(l10n.playlistSkipThose),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Duplicates.again),
          child: Text(l10n.playlistAddAnyway),
        ),
      ],
    );
  }
}
