import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/domain/audio_file.dart';
import '../../playback/application/audio_playback_controller.dart';
import '../../playback/domain/media_player.dart';
import '../../playback/domain/playback_queue.dart';
import '../../playback/presentation/album_art.dart';
import '../../playback/presentation/music_display_name.dart';
import '../../playback/presentation/now_playing_screen.dart';
import '../../playback/presentation/sliding_text.dart';

/// The persistent playback bar.
///
/// Persistent means present, not present-only-while-playing: it holds the
/// bottom of the shell from the first frame so the content area above it never
/// changes height when a track starts. It is a view of the player and holds
/// nothing itself, which is what lets playback continue while the owner
/// navigates anywhere else.
class PlaybackBar extends ConsumerWidget {
  /// Creates the bar.
  const PlaybackBar({super.key});

  /// The sleeve's size inside the bar.
  static const double artSize = 56;

  /// The bar's height, in logical pixels.
  ///
  /// Fixed rather than intrinsic: the content area is laid out above it, and a
  /// bar that changed height as its contents arrived would reflow the listing
  /// behind it. Derived from [artSize] rather than a second hardcoded number —
  /// a second copy is exactly what lets the margin drift out of step with the
  /// thing it exists to leave room around.
  static const double height = artSize + AppSpacing.sm * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(audioPlaybackControllerProvider);

    return Semantics(
      container: true,
      label: l10n.playbackBarLabel,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A skipped track is named above the bar rather than replacing
            // what is playing, because the queue has already moved on and the
            // owner is listening to the next one.
            if (state.lastSkipped case final skipped?)
              _SkipNotice(file: skipped),

            if (state.stage == AudioStage.allFailed) const _NothingPlayable(),

            const SizedBox(height: height, child: _Bar()),
          ],
        ),
      ),
    );
  }
}

/// The bar itself: what is playing, and the transport.
class _Bar extends ConsumerWidget {
  const _Bar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(audioPlaybackControllerProvider);
    final controller = ref.read(audioPlaybackControllerProvider.notifier);
    final current = state.current;
    final compact = Breakpoint.from(context).usesBottomNavigation;

    // A single track with a resume position asks before it starts.
    if (state.stage == AudioStage.offeringResume) return const _ResumePrompt();

    if (current == null) {
      return Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(
            Icons.music_note_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.playbackNothingPlaying,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      );
    }

    final entry = musicEntryForFile(ref, current);

    return Row(
      children: [
        const SizedBox(width: AppSpacing.sm),
        // The sleeve opens the player. A picture in a bar that is on screen
        // all session is the thing an owner reaches for when they want to see
        // what is playing.
        Semantics(
          button: true,
          child: InkWell(
            onTap: () => unawaited(NowPlayingScreen.show(context)),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: AlbumArt(
                coverId: entry.metadata.coverId,
                side: PlaybackBar.artSize - AppSpacing.sm,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: InkWell(
            onTap: () => unawaited(NowPlayingScreen.show(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The one line in the application that slides rather than
                  // ellipsising: on a phone this box is a hundred and fifty
                  // pixels wide, and half a track's name with a full stop
                  // after it is not a name.
                  SlidingText(
                    musicTitleForFile(ref, current, l10n),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    queueLabelOf(state.queue, l10n) ??
                        musicAlbumArtistForFile(ref, current, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Where the track has got to, beside the transport rather than under
        // the title, so it sits next to the controls that move it. Off the
        // phone layout, where the width is needed for the transport itself and
        // the full player is one tap away.
        if (!compact) ...[
          _Position(status: state.status),
          const SizedBox(width: AppSpacing.sm),
        ],
        // On every arrangement, including the phone, which it was not on
        // before. Stop and the chevron are still desktop-only — one is the
        // full player, one tap away on a phone, and the other is a button
        // nobody reaches for mid-song — but back is transport, and a bar
        // offering only forward is a bar that cannot return to the track that
        // just played.
        //
        // Never disabled: pressing back near the start of a track steps to the
        // one before it and pressing it later restarts this one, so there is
        // no point in a queue where it does nothing.
        IconButton(
          tooltip: l10n.audioPrevious,
          icon: const Icon(Icons.skip_previous),
          onPressed: () => unawaited(controller.previous()),
        ),
        IconButton(
          tooltip: state.isPlaying ? l10n.audioPause : l10n.audioPlay,
          icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () => unawaited(controller.togglePlaying()),
        ),
        // Disabled rather than hidden at the end of a queue, so the controls
        // do not move as it plays through.
        IconButton(
          tooltip: l10n.audioNext,
          icon: const Icon(Icons.skip_next),
          onPressed:
              state.queue.hasNext ||
                  (state.repeat != QueueRepeat.off && !state.queue.isEmpty)
              ? () => unawaited(controller.next())
              : null,
        ),
        if (!compact) ...[
          IconButton(
            tooltip: l10n.audioStop,
            icon: const Icon(Icons.stop),
            onPressed: () => unawaited(controller.stop()),
          ),
          IconButton(
            tooltip: l10n.audioOpenPlayer,
            icon: const Icon(Icons.expand_less),
            onPressed: () => unawaited(NowPlayingScreen.show(context)),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

/// The resume question, in the bar rather than over the screen: the owner is
/// somewhere else in the application, and a modal would interrupt it.
class _ResumePrompt extends ConsumerWidget {
  const _ResumePrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(audioPlaybackControllerProvider);
    final controller = ref.read(audioPlaybackControllerProvider.notifier);
    final at = state.resumeFrom ?? Duration.zero;

    return Row(
      children: [
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            l10n.audioResumePrompt(formatPlaybackPosition(at)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => unawaited(controller.startOver()),
          child: Text(l10n.audioStartOver),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () => unawaited(controller.resume()),
          child: Text(l10n.audioResume),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}

/// Which file was skipped, and nothing about why.
///
/// Why a track would not open is the same answer for every skip the queue
/// makes; which file it was is the whole of what the owner needs, and a reason
/// per line would bury the name.
class _SkipNotice extends ConsumerWidget {
  const _SkipNotice({required this.file});

  final AudioFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return _Notice(
      message: l10n.audioSkipped(musicTitleForFile(ref, file, l10n)),
      onDismiss: ref
          .read(audioPlaybackControllerProvider.notifier)
          .acknowledgeSkip,
    );
  }
}

/// Nothing in the selection could be played.
class _NothingPlayable extends ConsumerWidget {
  const _NothingPlayable();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Notice(
    message: AppLocalizations.of(context).audioNothingPlayable,
    // Dismissable, like the skip notice above it: the queue is already
    // cleared, and a report with no way to clear it stays for the rest of the
    // session.
    onDismiss: ref
        .read(audioPlaybackControllerProvider.notifier)
        .acknowledgeAllFailed,
  );
}

/// One line above the bar, with the way to clear it.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onDismiss, child: Text(l10n.dismiss)),
        ],
      ),
    );
  }
}

/// Where the track has got to, and how long it is.
///
/// Absent until the engine reports a duration: "00:00 / 00:00" beside a bar is
/// noise, and a track whose length the engine has not worked out yet has
/// nothing to divide by.
class _Position extends StatelessWidget {
  const _Position({required this.status});

  final PlaybackStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = status.duration;
    if (duration == null || duration == Duration.zero) {
      return const SizedBox.shrink();
    }

    return Text(
      '${formatPlaybackPosition(status.position)} / '
      '${formatPlaybackPosition(duration)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
