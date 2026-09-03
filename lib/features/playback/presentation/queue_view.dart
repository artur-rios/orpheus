import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import 'album_art.dart';
import 'music_display_name.dart';

/// What is queued, in the order it will play.
///
/// The one screen in this application that shows a sequence rather than a
/// grouping: everywhere else the library is artists and records, and here it
/// is the list the player is actually working through — which is the only way
/// to answer "what did shuffle decide" without waiting to hear it.
class QueueView extends ConsumerWidget {
  /// Creates the area.
  const QueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(audioPlaybackControllerProvider);
    final queue = state.queue;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          l10n.queueEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  queueLabelOf(queue, l10n) ?? l10n.destinationQueue,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.queuePosition(queue.index + 1, queue.tracks.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: queue.tracks.length,
            itemBuilder: (context, index) {
              final file = queue.tracks[index];
              final entry = musicEntryForFile(ref, file);
              final playing = index == queue.index;
              // A track the queue stepped over stays in the list, struck
              // through rather than removed: the owner is owed the fact that
              // it was meant to play and did not.
              final skipped = queue.skipped.contains(file);

              return ListTile(
                selected: playing,
                leading: AlbumArt(coverId: entry.metadata.coverId, side: 44),
                title: Text(
                  musicTitleOf(entry, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skipped
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                subtitle: Text(
                  musicArtistOf(entry, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: playing
                    ? Icon(
                        state.isPlaying
                            ? Icons.graphic_eq
                            : Icons.pause_circle_outline,
                        semanticLabel: l10n.queueNowPlaying,
                        color: theme.colorScheme.primary,
                      )
                    : Text(
                        entry.duration == null
                            ? ''
                            : formatPlaybackPosition(entry.duration!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                onTap: () => unawaited(
                  ref
                      .read(audioPlaybackControllerProvider.notifier)
                      .jumpTo(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
