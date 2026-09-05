import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/presentation/async_state_view.dart';
import '../domain/lyrics.dart';

/// The words of what is playing, following the music where the file says when
/// each line is sung.
///
/// It takes the place of the sleeve on the player rather than sitting under
/// it: both want the same space — the middle of the screen, as tall as the
/// window allows — and a screen showing a postage-stamp cover above four
/// visible lines of words would serve neither.
class LyricsPanel extends ConsumerWidget {
  /// Creates the panel for the track at [trackPath].
  const LyricsPanel({
    required this.trackPath,
    required this.height,
    super.key,
  });

  /// The track whose words are shown.
  final String trackPath;

  /// How tall the panel is, which the player works out from its window.
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lyrics = ref.watch(lyricsProvider(trackPath));
    final status = ref.watch(audioPlaybackControllerProvider).status;

    return SizedBox(
      height: height,
      child: Semantics(
        label: l10n.lyricsLabel,
        container: true,
        child: AsyncStateView<Lyrics?>(
          value: lyrics,
          onRetry: () => ref.invalidate(lyricsProvider(trackPath)),
          isEmpty: (words) => words == null || words.isEmpty,
          emptyBuilder: (context) => const _NoLyrics(),
          builder: (context, words) => _LyricLines(
            lyrics: words!,
            // Worked out here rather than inside the list so that the list is
            // a thing a test can hand a line number to.
            activeLine: words.lineIndexAt(status.position),
            onSeek: (at) => unawaited(
              ref
                  .read(audioPlaybackControllerProvider.notifier)
                  .seekTo(at),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the panel says about a track this machine holds no words for.
///
/// Which is most tracks in most libraries, so it says where words would have
/// to come from rather than only that there are none — and it says the other
/// half too, because "no lyrics" in a music player usually means "not
/// downloaded yet" and here it never will.
class _NoLyrics extends StatelessWidget {
  const _NoLyrics();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: AppSpacing.xl,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.lyricsNone,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.lyricsWhereTheyComeFrom,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lines themselves, scrolled so the one being sung is in the middle.
///
/// Every line is built, rather than a lazy list: a lyric sheet is tens of
/// lines, not thousands, and building all of them is what lets the view scroll
/// straight to a line that is a long way down — the state an owner is in every
/// time they open the words half way through a track.
class _LyricLines extends StatefulWidget {
  const _LyricLines({
    required this.lyrics,
    required this.activeLine,
    required this.onSeek,
  });

  final Lyrics lyrics;
  final int? activeLine;
  final void Function(Duration at) onSeek;

  @override
  State<_LyricLines> createState() => _LyricLinesState();
}

class _LyricLinesState extends State<_LyricLines> {
  /// How long the view leaves the owner where they scrolled to.
  ///
  /// Without this, a reader who scrolls ahead to see what is coming is dragged
  /// back to the current line the moment it changes, which is within a few
  /// seconds. With it, they get to read.
  static const Duration _followsAgainAfter = Duration(seconds: 6);

  /// One key per line, so the view can be told to bring a particular one into
  /// sight without knowing how tall any of them turned out.
  late List<GlobalKey> _keys;

  /// When the owner last scrolled the panel themselves.
  DateTime? _scrolledAt;

  @override
  void initState() {
    super.initState();
    _keys = _keysFor(widget.lyrics);
    // The player is often opened part-way through a track, so the first frame
    // already has a line to go to — and it is jumped to rather than scrolled,
    // because there was nothing on screen to scroll away from.
    _bringActiveIntoView(animate: false);
  }

  @override
  void didUpdateWidget(_LyricLines old) {
    super.didUpdateWidget(old);

    if (!identical(old.lyrics, widget.lyrics)) {
      _keys = _keysFor(widget.lyrics);
      _scrolledAt = null;
      _bringActiveIntoView(animate: false);

      return;
    }

    if (old.activeLine != widget.activeLine) _bringActiveIntoView();
  }

  List<GlobalKey> _keysFor(Lyrics lyrics) => [
    for (var index = 0; index < lyrics.lines.length; index++) GlobalKey(),
  ];

  /// Whether the view is currently following the music.
  bool get _isFollowing {
    final scrolled = _scrolledAt;

    return scrolled == null ||
        DateTime.now().difference(scrolled) > _followsAgainAfter;
  }

  /// Scrolls the line being sung to the middle of the panel.
  void _bringActiveIntoView({bool animate = true}) {
    final line = widget.activeLine;
    if (line == null || line >= _keys.length || !_isFollowing) return;

    // After the frame: on the first build the lines have no context yet, and
    // on a later one the line that has just become active may have changed
    // height as it took the active style.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final target = _keys[line].currentContext;
      if (target == null) return;

      // An owner who has asked the system for less movement gets the line put
      // where it belongs rather than slid there. The words still follow the
      // music; it is the sliding that stops.
      final still = !animate || MediaQuery.disableAnimationsOf(context);

      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: still ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _scrolledAt = DateTime.now();

        return false;
      },
      child: SingleChildScrollView(
        // Half a panel of padding at each end, so the first and the last line
        // can both sit in the middle where every other line does.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.lyrics.isSynced)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  l10n.lyricsNotSynced,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final (index, line) in widget.lyrics.lines.indexed)
              _Line(
                key: _keys[index],
                line: line,
                isActive: index == widget.activeLine,
                onTap: line.at == null ? null : () => widget.onSeek(line.at!),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line, lit while it is being sung.
class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.isActive,
    this.onTap,
    super.key,
  });

  final LyricLine line;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A timed gap between verses. It is kept as space rather than drawn,
    // which is what makes the highlight go out through an instrumental
    // instead of leaving the last line lit.
    if (line.text.isEmpty) return const SizedBox(height: AppSpacing.lg);

    final style = isActive
        ? theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );

    return InkWell(
      // A line with a time is a place in the track, so tapping it goes there.
      // A line without one is not, and stays plain text.
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        child: Text(line.text, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}
