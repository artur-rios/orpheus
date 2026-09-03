import 'dart:math' as math;

/// The envelope the sound bars are drawn from.
///
/// **What this is, stated plainly:** a synthesised envelope, not a measurement.
/// Nothing in this application decodes audio — the playback engine reports a
/// position and a duration and nothing about the waveform behind them — so
/// what the bars show is a figure computed from the track's identity and the
/// moment being played, and not the sound of the recording.
///
/// It is worth having anyway, and worth being precise about why. A row of bars
/// moving while music plays is a signal that something is playing, and it
/// costs nothing; what it must not do is pretend to be an analysis. So it is
/// built to the two properties that make it honest:
///
/// - **Deterministic.** The same second of the same track draws the same bars
///   every time it plays, on every machine. It is a function of the seed and
///   the position, and of nothing else.
/// - **Distinct.** Two tracks seed differently and therefore move differently,
///   so the instrument reads as belonging to what is playing rather than as
///   the same loop under everything.
///
/// The shape is three sine waves per band at unrelated rates — a slow swell, a
/// bar-length movement, and a fast flicker — under a tilt that keeps the low
/// bands heavier than the high ones, which is what every real spectrum does
/// and what makes the row read as a spectrum rather than as noise.
class TrackEnergy {
  /// Creates an envelope with [bands] bands, seeded by [seed].
  const TrackEnergy({required this.seed, this.bands = defaultBands});

  /// The envelope for the track at [path].
  ///
  /// Seeded from the path, so a track keeps its own movement across runs and
  /// across machines — the same property `coverIdOf` gets from hashing bytes,
  /// for the same reason: nothing may depend on a hash Dart is free to change
  /// between releases.
  factory TrackEnergy.forTrack(String path) {
    var hash = 0xcbf29ce484222325;
    for (final unit in path.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }

    return TrackEnergy(seed: hash);
  }

  /// How many bands an envelope carries unless asked otherwise.
  ///
  /// Sixteen, which is what a graphic equaliser shows and enough for the
  /// interpolation in the painter to draw a curve rather than a staircase.
  static const int defaultBands = 16;

  /// What seeds the movement.
  final int seed;

  /// How many bands this envelope carries.
  final int bands;

  /// How high band [band] stands at [position], 0 to 1.
  double levelAt({required int band, required Duration position}) {
    if (bands <= 0) return 0;

    final index = band.clamp(0, bands - 1);
    final seconds = position.inMilliseconds / 1000;

    // Three rates and three phases per band, all derived from the seed. The
    // rates are deliberately not multiples of each other: sines at related
    // rates re-align on a short cycle, and a bar that repeats every two
    // seconds reads as an animation rather than as a level.
    final slow = math.sin(seconds * _rate(index, 0, 0.45, 0.35) + _phase(index, 3));
    final beat = math.sin(seconds * _rate(index, 1, 2.70, 1.30) + _phase(index, 5));
    final flick = math.sin(seconds * _rate(index, 2, 7.10, 3.70) + _phase(index, 7));

    final mixed = 0.46 + 0.26 * slow + 0.17 * beat + 0.08 * flick;

    // Low bands heavier than high ones. Every recording has more energy at the
    // bottom, and an untilted row reads as a hedge rather than as a spectrum.
    final tilt = 1 - 0.42 * (index / math.max(1, bands - 1));

    return (mixed * tilt).clamp(0.0, 1.0);
  }

  /// A rate for band [band]'s [component]th sine, between [base] and
  /// `base + spread`.
  double _rate(int band, int component, double base, double spread) =>
      base + spread * _unit(band, component);

  /// A phase offset for band [band]'s [component]th sine.
  double _phase(int band, int component) =>
      _unit(band, component) * 2 * math.pi;

  /// A number in `[0, 1)`, determined by [seed], [band] and [component].
  double _unit(int band, int component) {
    var hash = seed ^ (band * 0x9E3779B97F4A7C15) ^ (component * 0x2545F4914F6CDD1D);
    hash &= 0xFFFFFFFFFFFFFFFF;
    // One round of a 64-bit mixer, which is enough to decorrelate the three
    // components of neighbouring bands — without it, band 5 and band 6 move
    // together and the row ripples in step.
    hash ^= hash >>> 33;
    hash = (hash * 0xFF51AFD7ED558CCD) & 0xFFFFFFFFFFFFFFFF;
    hash ^= hash >>> 29;

    return (hash & 0xFFFFFF) / 0x1000000;
  }
}
