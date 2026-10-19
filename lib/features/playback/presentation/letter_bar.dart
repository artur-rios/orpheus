import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/index_letter.dart';

/// A strip of letters beside a long list, and the jump each one makes.
///
/// A press anywhere on it asks for the letter under the finger, and so does
/// every letter the finger is dragged across, so the owner can run down the
/// strip and watch the list follow. A letter with nothing under it is dimmed
/// and asks for nothing: the strip keeps every letter so it never changes
/// shape between lists, and a dimmed one says why the list did not move.
///
/// Drawn from a pressed pointer rather than from tap and drag recognisers: a
/// press on a letter should jump at once, not after the arena has decided it
/// was not the start of a drag.
class LetterBar extends StatefulWidget {
  /// Creates the strip.
  const LetterBar({required this.available, required this.onLetter, super.key});

  /// The letters with something under them.
  final Set<String> available;

  /// What a press or a drag onto an available letter asks for.
  final ValueChanged<String> onLetter;

  /// The large letter shown beside the finger while the strip is pressed.
  static const Key bubbleKey = ValueKey('letter-bar-bubble');

  /// How wide the strip is.
  static const double width = AppSpacing.lg;

  @override
  State<LetterBar> createState() => _LetterBarState();
}

class _LetterBarState extends State<LetterBar> {
  final OverlayPortalController _bubble = OverlayPortalController();

  /// The letter under the finger, or `null` while the strip is not pressed.
  String? _current;

  /// Where the finger is, globally, for placing the bubble beside it.
  double _fingerY = 0;

  String _letterAt(Offset local) {
    final height = (context.size?.height ?? 1).clamp(1, double.infinity);
    final index = (local.dy / height * indexLetters.length).floor();

    return indexLetters[index.clamp(0, indexLetters.length - 1)];
  }

  void _press(PointerEvent event) {
    final letter = _letterAt(event.localPosition);
    setState(() => _fingerY = event.position.dy);
    _bubble.show();
    if (letter == _current) return;

    setState(() => _current = letter);
    if (widget.available.contains(letter)) widget.onLetter(letter);
  }

  void _release(PointerEvent event) {
    _bubble.hide();
    setState(() => _current = null);
  }

  /// The bubble, to the left of the strip at the finger's height.
  Widget _buildBubble(BuildContext context) {
    final theme = Theme.of(context);
    final letter = _current;
    final box = this.context.findRenderObject() as RenderBox?;
    if (letter == null || box == null || !box.attached) {
      return const SizedBox.shrink();
    }

    const side = AppSpacing.xxl + AppSpacing.md;
    final strip = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);
    final top = (_fingerY - side / 2)
        .clamp(0.0, math.max(0.0, screen.height - side))
        .toDouble();

    return Positioned(
      left: strip.left - side - AppSpacing.md,
      top: top,
      child: IgnorePointer(
        child: Material(
          key: LetterBar.bubbleKey,
          elevation: 4,
          color: theme.colorScheme.primaryContainer,
          shape: const CircleBorder(),
          child: SizedBox.square(
            dimension: side,
            child: Center(
              child: Text(
                letter,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: widget.available.contains(letter)
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.38,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;

    return OverlayPortal(
      controller: _bubble,
      overlayChildBuilder: _buildBubble,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _press,
        onPointerMove: _press,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: SizedBox(
          width: LetterBar.width,
          child: Column(
            children: [
              for (final letter in indexLetters)
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: widget.available.contains(letter),
                    label: l10n.musicJumpToLetter(letter),
                    onTap: widget.available.contains(letter)
                        ? () => widget.onLetter(letter)
                        : null,
                    excludeSemantics: true,
                    // Scaled down rather than dropped on a short window: a
                    // strip that skipped letters would make the owner guess
                    // which ones were missing.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        letter,
                        style: style?.copyWith(
                          fontWeight: letter == _current
                              ? FontWeight.bold
                              : null,
                          color: widget.available.contains(letter)
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list beside its [LetterBar], and the jump from a letter to a row.
///
/// Every row of the list is one height, and every row of tiles is one height,
/// which is what lets a letter's first name be turned into a distance down the
/// list without the rows in between ever being built: the whole length of the
/// list, divided by its number of rows, is the height of one.
class LetterIndexedScroll extends StatefulWidget {
  /// Creates the list and its strip.
  const LetterIndexedScroll({
    required this.names,
    required this.builder,
    this.columnsFor,
    this.rowSpacing = 0,
    super.key,
  });

  /// What each item is sorted and filed by, in the order the list shows them.
  final List<String?> names;

  /// The list, scrolled by the controller it is handed.
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// How many items share a row at the width the list is given — the grid's
  /// own count for tiles, or `null` for rows, one item apiece.
  final int Function(double width)? columnsFor;

  /// The gap between two rows of tiles, which the length of the list holds
  /// one fewer of than it holds rows.
  final double rowSpacing;

  @override
  State<LetterIndexedScroll> createState() => _LetterIndexedScrollState();
}

class _LetterIndexedScrollState extends State<LetterIndexedScroll> {
  final ScrollController _controller = ScrollController();

  /// The width the list was last laid out at, for the grid's column count.
  double _width = 0;

  late Map<String, int> _starts = firstIndexByLetter(widget.names);

  @override
  void didUpdateWidget(LetterIndexedScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.names, widget.names)) {
      _starts = firstIndexByLetter(widget.names);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jump(String letter) {
    final index = _starts[letter];
    if (index == null || !_controller.hasClients) return;

    final position = _controller.position;
    final columns = math.max(1, widget.columnsFor?.call(_width) ?? 1);
    final rows = (widget.names.length / columns).ceil();
    if (rows == 0) return;

    final length = position.maxScrollExtent + position.viewportDimension;
    final stride = (length + widget.rowSpacing) / rows;
    final target = (index ~/ columns) * stride;

    _controller.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;

            return widget.builder(context, _controller);
          },
        ),
      ),
      LetterBar(available: _starts.keys.toSet(), onLetter: _jump),
    ],
  );
}
