import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/story_palette.dart';
import '../domain/stats_story.dart';
import '../domain/story_share.dart';
import 'story_card_view.dart';

/// The statistics, told a card at a time.
///
/// The same numbers the statistics screen lists, arranged to be looked at
/// rather than read: one fact per card, tapped through, and any of them worth
/// keeping can leave as a picture.
///
/// Portrait whatever the window is. On a phone that is the screen; on a
/// desktop it is a card in the middle of it, which is not a compromise — a
/// story is a portrait format everywhere it is shared, and a card rendered
/// letterboxed would be a picture nobody can post.
class StatsStoryScreen extends ConsumerStatefulWidget {
  /// Creates the screen over [cards].
  const StatsStoryScreen({required this.cards, super.key});

  /// The story to tell.
  final List<StoryCard> cards;

  /// How long a card is shown before the next one, where it advances at all.
  static const Duration cardDuration = Duration(seconds: 6);

  /// Opens the story over whatever is showing.
  static Future<void> show(BuildContext context, List<StoryCard> cards) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => StatsStoryScreen(cards: cards),
        ),
      );

  @override
  ConsumerState<StatsStoryScreen> createState() => _StatsStoryScreenState();
}

class _StatsStoryScreenState extends ConsumerState<StatsStoryScreen> {
  static final Logger _log = Logger('stats');

  final GlobalKey _cardKey = GlobalKey();

  int _index = 0;
  bool _sending = false;
  Timer? _advance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  /// Starts the wait for the next card, where the owner wants one.
  ///
  /// Not where they have asked the system for less animation: a screen that
  /// moves on by itself is exactly what that setting is about, and somebody
  /// who has turned it on gets a story they tap through at their own pace.
  /// It is also what lets a widget test settle.
  void _restartTimer() {
    _advance?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (_index >= widget.cards.length - 1) return;

    _advance = Timer(StatsStoryScreen.cardDuration, () => _go(1));
  }

  void _go(int by) {
    final next = _index + by;
    if (next < 0) return;
    if (next >= widget.cards.length) {
      Navigator.of(context).pop();

      return;
    }

    setState(() => _index = next);
    _restartTimer();
  }

  /// Renders the card on screen and hands it to the platform.
  ///
  /// The picture is taken from the widget the owner is looking at rather than
  /// from a second layout built to match it, so what they send is what they
  /// saw. Three times the logical size, which is what makes the text on it
  /// hold up when a social application re-encodes it.
  Future<void> _send() async {
    if (_sending) return;

    setState(() => _sending = true);
    _advance?.cancel();

    final l10n = AppLocalizations.of(context);
    final share = ref.read(storyShareProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final png = await _render();
      if (png == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.storyShareFailed)));

        return;
      }

      final outcome = await share.send(
        png,
        fileName: 'orpheus-story.png',
        text: l10n.storyMadeWith,
      );

      final said = switch (outcome) {
        StoryShareOutcome.shared => l10n.storyShared,
        StoryShareOutcome.saved => l10n.storySaved,
        StoryShareOutcome.failed => l10n.storyShareFailed,
        // Nothing to say about a sheet the owner closed. They know.
        StoryShareOutcome.cancelled => null,
      };
      if (said != null) {
        messenger.showSnackBar(SnackBar(content: Text(said)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _restartTimer();
      }
    }
  }

  /// The card on screen as PNG bytes, or `null` where it could not be drawn.
  Future<Uint8List?> _render() async {
    try {
      // Waited for before anything is captured. Turning the button to its
      // busy state marks this subtree as needing paint, and a boundary is not
      // allowed to be rendered while that is true — without this, the first
      // press produces nothing and the owner is told the picture could not be
      // made.
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return bytes?.buffer.asUint8List();
    } on Object catch (error) {
      _log.warning('the story card could not be rendered', error);

      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colours = StoryPalette.forCard(_index, scheme);
    final share = ref.watch(storyShareProvider);

    return Scaffold(
      backgroundColor: colours.bottom,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AspectRatio(
                  // The portrait shape every place this ends up expects.
                  aspectRatio: 9 / 16,
                  child: Stack(
                    children: [
                      // What the picture is taken from: the card and nothing over
                      // it. The progress bars, the close button and the share button
                      // sit outside this boundary deliberately — they are how the
                      // owner drives the story, and nobody wants them in the picture
                      // they post.
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: StoryCardView(
                            card: widget.cards[_index],
                            colours: colours,
                            showsFooter: true,
                          ),
                        ),
                      ),
                      Positioned.fill(child: _taps(l10n)),
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: _Progress(
                          count: widget.cards.length,
                          index: _index,
                          colours: colours,
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.lg,
                        right: AppSpacing.xs,
                        child: IconButton(
                          tooltip: l10n.storyClose,
                          icon: Icon(Icons.close, color: colours.foreground),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Below the card rather than over it. Everything inside that
              // boundary is in the picture, and a button lying across the
              // corner of every story anybody posts is the one thing this had
              // to avoid.
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: _SendButton(
                    busy: _sending,
                    colours: colours,
                    label: share.sharesToApps
                        ? l10n.storyShare
                        : l10n.storySave,
                    icon: share.sharesToApps
                        ? Icons.ios_share
                        : Icons.download_outlined,
                    onPressed: _send,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The two halves that move the story, back and forward.
  Widget _taps(AppLocalizations l10n) => Row(
    children: [
      Expanded(
        child: Semantics(
          button: true,
          label: l10n.storyPrevious,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _go(-1),
          ),
        ),
      ),
      Expanded(
        child: Semantics(
          button: true,
          label: l10n.storyNext,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _go(1),
          ),
        ),
      ),
    ],
  );
}

/// The bar of segments across the top: one per card, filled up to this one.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.count,
    required this.index,
    required this.colours,
  });

  final int count;
  final int index;
  final StoryColours colours;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var position = 0; position < count; position++) ...[
        Expanded(
          child: Container(
            height: AppSpacing.xs / 2,
            decoration: BoxDecoration(
              color: position <= index
                  ? colours.foreground
                  : colours.muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        if (position < count - 1) const SizedBox(width: AppSpacing.xs),
      ],
    ],
  );
}

/// The one button that takes the card out of the application.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.busy,
    required this.colours,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final bool busy;
  final StoryColours colours;
  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: colours.foreground,
      foregroundColor: colours.bottom,
      minimumSize: const Size.fromHeight(AppSpacing.xxl),
    ),
    onPressed: busy ? null : () => unawaited(onPressed()),
    icon: busy
        ? SizedBox.square(
            dimension: AppSpacing.md,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colours.bottom,
            ),
          )
        : Icon(icon),
    label: Text(label),
  );
}
