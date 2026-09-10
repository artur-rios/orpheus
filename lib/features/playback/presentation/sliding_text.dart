import 'package:flutter/material.dart';

/// One line of text that slides itself back and forth when it will not fit.
///
/// What it exists for is the track name in the playback bar on a phone. There
/// the line is a hundred and fifty pixels wide and the names are not, so an
/// ellipsis is not a graceful truncation of the title — it is most of the
/// title missing, and the owner has no way to see the rest of it short of
/// opening the full player.
///
/// So the line travels: it holds still long enough to be read from the start,
/// walks left until its end is showing, holds again, and walks back. Back and
/// forth rather than a loop that wraps around, because a wrap puts the end of
/// the name next to its beginning and reads as a different sentence.
///
/// Two things turn the motion off, and both leave a perfectly ordinary
/// ellipsised line behind. Text that already fits never moves — a bar that
/// twitched for a three-letter title would be motion for its own sake. And an
/// owner who has asked the system for less animation gets none: this is a
/// decoration around a name, not information, and it is exactly the kind of
/// perpetual movement that setting exists to stop. That is also what keeps
/// this widget out of the way of `pumpAndSettle`, which never settles in a
/// tree holding a ticker that never stops.
class SlidingText extends StatefulWidget {
  /// Creates a line showing [text].
  const SlidingText(
    this.text, {
    this.style,
    this.textAlign = TextAlign.start,
    super.key,
  });

  /// What to show.
  final String text;

  /// How to draw it. The ambient style where this is `null`, as [Text] does.
  final TextStyle? style;

  /// How the line sits in its box while it is short enough not to move.
  final TextAlign textAlign;

  /// How fast the line travels, in logical pixels a second.
  ///
  /// Reading pace rather than a pace chosen to look busy: a name twice as long
  /// as its box takes twice as long to cross it, which is the point of moving
  /// at a speed rather than over a fixed duration.
  static const double pixelsPerSecond = 30;

  /// How long the line rests at each end before setting off again.
  static const Duration pause = Duration(seconds: 2);

  @override
  State<SlidingText> createState() => _SlidingTextState();
}

class _SlidingTextState extends State<SlidingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// How far the line has to travel for its end to show, or zero where it
  /// fits.
  double _overflow = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final still = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, box) {
        final wanted = _sizeOf(widget.text, style, box.maxWidth);
        final width = wanted.width;
        final overflow = still ? 0.0 : (width - box.maxWidth).clamp(0.0, width);

        // In a post-frame callback rather than here: this runs during layout,
        // and starting or stopping an animation is a change to the tree.
        if (overflow != _overflow) {
          _overflow = overflow;
          WidgetsBinding.instance.addPostFrameCallback((_) => _retime());
        }

        if (overflow <= 0) {
          return Text(
            widget.text,
            style: style,
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // The whole name is drawn, and the box is what hides the part of it
        // that is off the end — so what slides is the same single line rather
        // than a second copy of a truncated one.
        //
        // The measured height is given back explicitly, because an
        // `OverflowBox` takes the largest size its constraints allow and the
        // one place this widget is actually used — a column inside the
        // playback bar — offers it no height at all. Left to take the biggest
        // of that, the line was laid out into an unbounded box and drawn
        // nowhere: on a phone the bar showed a sleeve, a transport and a blank
        // space where the name of every long-titled track should have been.
        return SizedBox(
          height: wanted.height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.translate(
                offset: Offset(-_travelled(overflow), 0),
                child: child,
              ),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: width,
                maxHeight: wanted.height,
                child: Text(
                  widget.text,
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// How large [text] wants to be on one line, measured rather than guessed.
  ///
  /// [ceiling] bounds the width so that a pathological name does not lay out
  /// to tens of thousands of pixels before being asked how wide it is; it is
  /// generous enough that nothing an owner would recognise as a title reaches
  /// it. The height is taken as it comes, and matters as much as the width:
  /// it is what the sliding line is given to sit in.
  Size _sizeOf(String text, TextStyle style, double ceiling) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: double.infinity);

    final size = Size(painter.width, painter.height);
    painter.dispose();

    return ceiling.isFinite
        ? Size(size.width.clamp(0.0, ceiling * 20), size.height)
        : size;
  }

  /// Where the line has got to, given how far it has to go.
  ///
  /// The controller runs 0 to 1 over one whole round trip, and this is the
  /// shape of that trip: rest, out, rest, back. Held at each end because a
  /// line that turned round the instant it arrived would never be still long
  /// enough for its end to be read.
  double _travelled(double overflow) {
    final crossing = _crossing(overflow).inMicroseconds;
    final resting = SlidingText.pause.inMicroseconds;
    final whole = crossing * 2 + resting * 2;
    final at = _controller.value * whole;

    if (at < resting) return 0;
    if (at < resting + crossing) return overflow * (at - resting) / crossing;
    if (at < resting * 2 + crossing) return overflow;

    return overflow * (1 - (at - resting * 2 - crossing) / crossing);
  }

  /// How long one crossing takes, at the reading pace.
  Duration _crossing(double overflow) => Duration(
    microseconds:
        (overflow / SlidingText.pixelsPerSecond * Duration.microsecondsPerSecond)
            .round(),
  );

  /// Starts, restarts or stops the trip for whatever the line now has to
  /// travel.
  void _retime() {
    if (!mounted) return;

    if (_overflow <= 0) {
      _controller.stop();
      _controller.value = 0;

      return;
    }

    _controller
      ..duration = _crossing(_overflow) * 2 + SlidingText.pause * 2
      ..value = 0
      ..repeat();
  }
}
