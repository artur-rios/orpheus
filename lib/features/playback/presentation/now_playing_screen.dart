import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../domain/media_player.dart';
import '../domain/playback_queue.dart';
import 'album_art.dart';
import 'music_display_name.dart';
import 'sound_bars.dart';

/// The full player.
///
/// There is no drawn hardware on this screen and there never was going to be.
/// What an owner is listening to is a track: it has a name, it has a sleeve,
/// and it is making a sound right now. So that is the screen — the record's own
/// picture as large as the window allows, what is playing named underneath it,
/// and the bars, which move while the music does and settle when it stops.
class NowPlayingScreen extends ConsumerWidget {
  /// Creates the screen.
  const NowPlayingScreen({super.key});

  /// The largest the sleeve is ever drawn, and the smallest.
  ///
  /// Bounded at the top because a cover blown up to fill a wide window is a
  /// low-resolution picture stretched past what it holds; bounded at the
  /// bottom because below this it stops being the thing the screen is about.
  static const double coverMaximum = 420;

  /// See [coverMaximum].
  static const double coverMinimum = 120;

  /// Whether a [NowPlayingScreen] is currently on screen.
  ///
  /// What [show] checks before pushing another one: the shell's own auto-open
  /// and the playback bar's button are two independent paths to the same
  /// route, and either could otherwise stack a second copy on top of a first
  /// that is already open.
  static bool _open = false;

  /// Pushes the full-window player over [context], unless one is already open.
  static Future<void> show(BuildContext context) async {
    if (_open) return;

    _open = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
      );
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(audioPlaybackControllerProvider);
    final controller = ref.read(audioPlaybackControllerProvider.notifier);
    final current = state.current;
    final entry = current == null ? null : musicEntryForFile(ref, current);

    return Scaffold(
      appBar: AppBar(
        // The player is a place the owner came *to*, so the way out of it is
        // the ordinary one — a down chevron, pointing back at the bar it rose
        // from, rather than a cross that reads as closing what is playing.
        leading: IconButton(
          tooltip: l10n.audioClosePlayer,
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          queueLabelOf(state.queue, l10n) ?? l10n.appTitle,
          style: theme.textTheme.titleMedium,
        ),
        actions: const [_RepeatButton(), SizedBox(width: AppSpacing.sm)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            // The sleeve takes what is left after the words, the bars and the
            // transport have theirs — bounded both ways, so a tall narrow
            // window does not print a postage stamp and a wide one does not
            // blow a 300-pixel picture up to fill it.
            final side = math
                .min(
                  viewport.maxWidth - AppSpacing.lg * 2,
                  viewport.maxHeight * 0.42,
                )
                .clamp(coverMinimum, coverMaximum)
                .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewport.maxHeight - AppSpacing.lg * 2,
                  minWidth: viewport.maxWidth - AppSpacing.lg * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RaisedAlbumArt(
                      coverId: entry?.metadata.coverId,
                      side: side,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      // Never the file name: the metadata title, the same one
                      // the bar and the browsing area agree a track is called.
                      current == null
                          ? l10n.playbackNothingPlaying
                          : musicTitleForFile(ref, current, l10n),
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (current != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        // The record's artist rather than the track's
                        // performer: it is whose record this is, which is what
                        // the browsing area files it under.
                        musicAlbumArtistForFile(ref, current, l10n),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        musicAlbumForFile(ref, current, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Semantics(
                        label: l10n.audioSoundBarsLabel,
                        child: SoundBars(
                          isPlaying: state.isPlaying,
                          position: state.status.position,
                          height: viewport.maxHeight < 620 ? 72 : 120,
                          energy: current == null
                              ? null
                              : ref.watch(trackEnergyProvider(current.path)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _Progress(status: state.status),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Stop, back, play, forward — the order every machine with
                    // these four keys prints them in.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.audioStop,
                          iconSize: 36,
                          icon: const Icon(Icons.stop),
                          onPressed: current == null
                              ? null
                              : () => unawaited(controller.stop()),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          tooltip: l10n.audioPrevious,
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: current == null
                              ? null
                              : () => unawaited(controller.previous()),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          tooltip: state.isPlaying
                              ? l10n.audioPause
                              : l10n.audioPlay,
                          iconSize: 72,
                          icon: Icon(
                            state.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                          ),
                          onPressed: current == null
                              ? null
                              : () => unawaited(controller.togglePlaying()),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          tooltip: l10n.audioNext,
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next),
                          onPressed:
                              state.queue.hasNext ||
                                  (state.repeat != QueueRepeat.off &&
                                      !state.queue.isEmpty)
                              ? () => unawaited(controller.next())
                              : null,
                        ),
                      ],
                    ),

                    // The volume lives here and not in the bar: on a phone the
                    // hardware keys are the volume, and on a desktop this is
                    // the screen an owner is on when they reach for it.
                    if (Breakpoint.from(context) != Breakpoint.phone) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: const _Volume(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// What happens when the queue runs out.
class _RepeatButton extends ConsumerWidget {
  const _RepeatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = ref.watch(audioPlaybackControllerProvider).repeat;

    return IconButton(
      tooltip: switch (mode) {
        QueueRepeat.off => l10n.audioRepeatOff,
        QueueRepeat.all => l10n.audioRepeatAll,
        QueueRepeat.one => l10n.audioRepeatOne,
      },
      // Off is drawn, not hidden: a control that vanished when it was doing
      // nothing would be one the owner could not find to turn on.
      color: mode == QueueRepeat.off
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.primary,
      icon: Icon(
        mode == QueueRepeat.one ? Icons.repeat_one : Icons.repeat,
      ),
      onPressed: () => unawaited(
        ref.read(audioPlaybackControllerProvider.notifier).cycleRepeat(),
      ),
    );
  }
}

/// How loud playback is.
class _Volume extends ConsumerWidget {
  const _Volume();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final volume = ref.watch(preferencesControllerProvider).volume;

    return Row(
      children: [
        Icon(
          volume == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          semanticLabel: l10n.audioVolume,
        ),
        Expanded(
          child: Slider(
            value: volume,
            onChanged: (next) => unawaited(
              ref.read(preferencesControllerProvider.notifier).setVolume(next),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the track has got to, and how to move it.
///
/// A slider rather than a plain bar: an owner watching a player expects the
/// line under it to be the thing they drag.
class _Progress extends ConsumerStatefulWidget {
  const _Progress({required this.status});

  final PlaybackStatus status;

  @override
  ConsumerState<_Progress> createState() => _ProgressState();
}

class _ProgressState extends ConsumerState<_Progress> {
  /// Where the owner has dragged to, while they are dragging.
  ///
  /// The engine keeps reporting the position it is actually at for as long as
  /// a drag lasts, and a slider that took its value from that would spring
  /// back under the thumb on every report. This is the thumb's own position
  /// until the drag ends, and `null` at every other time.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = widget.status.duration;
    final elapsed = widget.status.position;

    final fraction = duration == null || duration == Duration.zero
        ? null
        : (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final value = _dragging ?? fraction;

    final label = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            // Room to grab, without a knob the size of a coin sitting on a
            // four-pixel line.
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value ?? 0,
            // A track whose length the engine has not worked out yet cannot be
            // seeked into: there is nothing to be a fraction of.
            onChanged: duration == null
                ? null
                : (next) => setState(() => _dragging = next),
            onChangeEnd: duration == null
                ? null
                : (next) {
                    setState(() => _dragging = null);
                    unawaited(
                      ref
                          .read(audioPlaybackControllerProvider.notifier)
                          .seekTo(duration * next),
                    );
                  },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatPlaybackPosition(
                // What the thumb says while it is being dragged, so the time
                // under it is the time it would seek to rather than the time
                // playback has reached behind it.
                _dragging == null || duration == null
                    ? elapsed
                    : duration * _dragging!,
              ),
              style: label,
            ),
            if (duration != null)
              Text(formatPlaybackPosition(duration), style: label),
          ],
        ),
      ],
    );
  }
}
