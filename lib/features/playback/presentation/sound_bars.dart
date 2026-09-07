import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../domain/track_energy.dart';

/// The bars that move with the music on the player screen.
///
/// What they are drawn from is a [TrackEnergy]: the spectrum of the recording,
/// measured from its own decoded samples, wherever the analysis of the track
/// has been done — and the stand-in for the second or so before it lands on
/// first play, and for a file that could not be decoded. Which one it is
/// holding is not this widget's business; both answer the same question, and
/// the provider that composes them decides.
///
/// The widget's own job is the part the spectrum does not cover: reading
/// between the position reports the engine sends, so the bars move at the
/// frame rate rather than a few times a second, and settling them when the
/// music stops. A pause settles them rather than freezing them mid-swell:
/// what an owner sees when they press pause is the sound falling away, which
/// is what pausing actually did.
class SoundBars extends StatefulWidget {
  /// Creates the visualiser.
  const SoundBars({
    required this.isPlaying,
    required this.position,
    this.energy,
    this.bars = 56,
    this.height = 140,
    super.key,
  });

  /// Whether audio is running: the bars follow while it is and lie down when
  /// it is not.
  final bool isPlaying;

  /// Where playback has reached, as the engine last reported it.
  ///
  /// Reported a few times a second, which is nowhere near a frame rate — so
  /// the widget carries it forward itself between reports (see
  /// [_SoundBarsState._elapsed]). Without that the bars would step a few times
  /// a second however smooth the envelope is.
  final Duration position;

  /// The track's envelope, or `null` for an instrument with nothing to show.
  final TrackEnergy? energy;

  /// How many bars are drawn.
  final int bars;

  /// How tall the whole instrument is, in logical pixels.
  final double height;

  @override
  State<SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<SoundBars>
    with SingleTickerProviderStateMixin {
  /// How much of the way toward the envelope one frame moves the bars.
  static const double _risesBy = 0.06;

  /// How much of the way back down one frame moves them once it stops.
  ///
  /// Slower than the rise: sound arrives faster than it dies away, and a
  /// settle that matched the rise reads as the bars being switched off.
  static const double _fallsBy = 0.04;

  /// Drives one repaint per frame while there is anything to move.
  late final Ticker _ticker = createTicker(_onTick);

  /// When the position now on the widget was reported.
  DateTime _reportedAt = DateTime.now();

  /// How far the bars have risen toward what the envelope says, 0 to 1.
  double _energyIn = 0;

  @override
  void didUpdateWidget(SoundBars oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.position != widget.position) _reportedAt = DateTime.now();
    if (oldWidget.isPlaying != widget.isPlaying) _apply();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  /// Runs or rests, and honours a request for less motion.
  ///
  /// Reduced motion is not "the same thing, slower": the bars stand at the
  /// levels of the moment playback is at and do not move at all, which is the
  /// picture the instrument makes without the motion somebody asked the system
  /// not to show them.
  void _apply() {
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_ticker.isActive) _ticker.stop();
      setState(() => _energyIn = widget.isPlaying ? 1 : 0);

      return;
    }

    // Started for the settle as well as for the run: the bars come down over
    // several frames after a pause, and [_onTick] is what stops the ticker
    // once they have arrived.
    if (!_ticker.isActive) _ticker.start();
  }

  /// Moves the bars one frame, and rests once there is nothing left to move.
  ///
  /// The stepping lives here rather than in `build` — where it was, along with
  /// a post-frame callback that asked for the next frame — because a widget
  /// that advances an animation while it is being built advances it once per
  /// rebuild rather than once per frame: the rise ran at whatever rate the
  /// player above happened to report positions at.
  void _onTick(Duration _) {
    final target = widget.isPlaying ? 1.0 : 0.0;
    final next = widget.isPlaying
        ? math.min(target, _energyIn + _risesBy)
        : math.max(target, _energyIn - _fallsBy);

    // While it plays a frame is due whatever the level is doing, because the
    // position has moved on and the bars are read from it. Once it stops and
    // the settle is over there is nothing left to draw.
    if (!widget.isPlaying && next == _energyIn) {
      _ticker.stop();

      return;
    }

    setState(() => _energyIn = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Where the music is now: the last reported position, carried forward by
  /// the clock for as long as it has been running.
  Duration get _elapsed {
    if (!widget.isPlaying) return widget.position;

    return widget.position + DateTime.now().difference(_reportedAt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SoundBarsPainter(
            energy: widget.energy,
            position: _elapsed,
            energyIn: _energyIn,
            bars: widget.bars,
            hot: scheme.primary,
            cool: scheme.tertiary,
          ),
        ),
      ),
    );
  }
}

/// Draws the bars for one frame.
class SoundBarsPainter extends CustomPainter {
  /// Creates the painter.
  const SoundBarsPainter({
    required this.position,
    required this.energyIn,
    required this.bars,
    required this.hot,
    required this.cool,
    this.energy,
  });

  /// The track's envelope, or `null` for an instrument with nothing to show.
  final TrackEnergy? energy;

  /// Where the music is.
  final Duration position;

  /// How much of the level to apply, 0 to 1.
  final double energyIn;

  /// How many bars to draw.
  final int bars;

  /// The colour of a bar at the bottom of the range.
  final Color hot;

  /// The colour of a bar at the top of it.
  final Color cool;

  /// What a bar stands at with nothing playing.
  ///
  /// Not zero: an instrument with nothing on it is still an instrument, and a
  /// row of bars flat against the floor reads as a broken widget rather than
  /// as silence.
  static const double resting = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars <= 0 || size.isEmpty) return;

    // Mirrored about the middle, growing up and down together: it is what a
    // level meter looks like laid on its side, and it keeps the block of
    // colour centred on the line the title above it is centred on.
    final middle = size.height / 2;
    final pitch = size.width / bars;
    final width = pitch * 0.62;
    final radius = Radius.circular(width / 2);

    for (var index = 0; index < bars; index++) {
      final level = levelFor(index);
      final half = middle * level;
      final centre = pitch * (index + 0.5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            centre - width / 2,
            middle - half,
            centre + width / 2,
            middle + half,
          ),
          radius,
        ),
        Paint()
          ..color = Color.lerp(hot, cool, index / math.max(1, bars - 1))!
              .withValues(
                // Lit in proportion to how far it has risen, so the loud bars
                // read as the loud ones rather than the tall ones.
                alpha: 0.45 + 0.55 * level,
              ),
      );
    }
  }

  /// How high the bar at [index] stands, 0 to 1.
  ///
  /// There are more bars than the envelope has bands — sixteen bands drawn as
  /// fifty-six bars — so a bar between two bands is read as a blend of them. A
  /// row of sixteen wide blocks would be the same data and a worse picture:
  /// what the eye reads as a spectrum is a curve, and the curve is what the
  /// interpolation restores.
  double levelFor(int index) {
    final envelope = energy;
    if (envelope == null || bars <= 1) return resting;

    final band = index / (bars - 1) * (envelope.bands - 1);
    final lower = band.floor();
    final upper = math.min(lower + 1, envelope.bands - 1);
    final into = band - lower;

    final from = envelope.levelAt(band: lower, position: position);
    final to = envelope.levelAt(band: upper, position: position);
    final level = from + (to - from) * into;

    return resting + (level - resting).clamp(0, 1) * energyIn;
  }

  @override
  bool shouldRepaint(SoundBarsPainter old) =>
      old.position != position ||
      old.energyIn != energyIn ||
      !identical(old.energy, energy) ||
      old.bars != bars ||
      old.hot != hot ||
      old.cool != cool;
}
