import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../domain/track_energy.dart';

/// The bars that move with the music on the player screen.
///
/// What they are drawn from is stated on [TrackEnergy], and it is worth
/// repeating here where it is visible: the envelope is synthesised from the
/// track's identity, not measured from its sound. Nothing in this application
/// decodes audio. What the instrument honestly is, is a sign that something is
/// playing, deterministic per track and per second so it belongs to the track
/// rather than looping the same shape under everything.
///
/// With nothing playing the bars rest. A pause settles them rather than
/// freezing them mid-swell: what an owner sees when they press pause is the
/// sound falling away, which is what pausing actually did.
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
  /// Drives one repaint per frame while the music runs.
  late final Ticker _ticker = createTicker((_) => setState(() {}));

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
    final reduced = MediaQuery.disableAnimationsOf(context);

    if (reduced || !widget.isPlaying) {
      if (_ticker.isActive) _ticker.stop();
      setState(() => _energyIn = reduced && widget.isPlaying ? 1 : 0);

      return;
    }

    if (!_ticker.isActive) _ticker.start();
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

    // Toward full while it plays and back down when it stops, a step a frame:
    // the settle is the only motion the bars make of their own accord, and it
    // is what keeps a pause from looking like a freeze.
    if (_ticker.isActive) {
      _energyIn = math.min(1, _energyIn + 0.06);
    } else if (_energyIn > 0 && !widget.isPlaying) {
      _energyIn = math.max(0, _energyIn - 0.04);
      if (_energyIn > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }

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
