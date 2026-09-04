import 'dart:math' as math;
import 'dart:typed_data';

/// What the sound bars are drawn from: how much of the sound sits in each band
/// of the spectrum, at a given moment of a track.
///
/// There are two of these, and the difference between them is the difference
/// between showing the music and showing that music is playing:
///
/// - [MeasuredEnergy] is the real thing — the spectrum of the recording,
///   computed from the decoded samples. It is what the bars show whenever the
///   analysis for the track has been done.
/// - [SynthesisedEnergy] is the stand-in, computed from the track's identity
///   and nothing else. It is what the bars show for the second or two before
///   the analysis lands, and for a file that could not be decoded.
///
/// Both answer the same question the painter asks, so nothing above this line
/// has to know which one it is holding.
abstract class TrackEnergy {
  /// Allows subclasses to be constant.
  const TrackEnergy();

  /// How many bands an envelope carries unless asked otherwise.
  ///
  /// Sixteen, which is what a graphic equaliser shows and enough for the
  /// interpolation in the painter to draw a curve rather than a staircase.
  static const int defaultBands = 16;

  /// How many bands this envelope carries.
  int get bands;

  /// How high band [band] stands at [position], 0 to 1.
  double levelAt({required int band, required Duration position});
}

/// The spectrum of a recording, measured from its own samples.
///
/// A grid: one row per analysed frame of audio, one column per band, each cell
/// a level from 0 to 255. Bytes rather than doubles because of what this is
/// for — a bar a hundred and forty pixels tall cannot show more than that, and
/// a byte a band is what makes a four-minute track a hundred kilobytes of
/// cache instead of half a megabyte.
///
/// Frames land about thirty times a second, which is under a display's frame
/// rate, so [levelAt] reads between two of them rather than stepping from one
/// to the next.
class MeasuredEnergy extends TrackEnergy {
  /// Creates a measured envelope over [levels], `frames * bands` bytes in
  /// row-major order, one row every [frame].
  const MeasuredEnergy({
    required this.levels,
    required this.bands,
    required this.frame,
  });

  /// Reads back what [toBytes] wrote, or answers `null` for anything else.
  ///
  /// Anything else includes a cache file from an older version of this
  /// application: a stored analysis is a cache, and a cache that cannot be
  /// read is re-computed rather than repaired.
  static MeasuredEnergy? fromBytes(Uint8List bytes) {
    if (bytes.length < _headerLength) return null;

    final header = ByteData.sublistView(bytes, 0, _headerLength);
    if (header.getUint32(0, Endian.little) != _magic) return null;
    if (header.getUint8(4) != _version) return null;

    final bands = header.getUint16(5, Endian.little);
    final micros = header.getUint32(7, Endian.little);
    if (bands <= 0 || micros <= 0) return null;

    final levels = Uint8List.sublistView(bytes, _headerLength);
    if (levels.length < bands || levels.length % bands != 0) return null;

    return MeasuredEnergy(
      levels: levels,
      bands: bands,
      frame: Duration(microseconds: micros),
    );
  }

  /// `ORPB`, little-endian, so a stray file in the cache directory says what
  /// it is to anyone who opens it.
  static const int _magic = 0x4250524f;

  /// The layout version. Bumped when the grid's meaning changes, which is what
  /// makes every stored analysis from before the change be re-computed.
  static const int _version = 1;

  /// Magic, version, band count, frame interval.
  static const int _headerLength = 11;

  /// The grid, `frames * bands` bytes, a row per frame.
  final Uint8List levels;

  @override
  final int bands;

  /// How much of the track one row covers.
  final Duration frame;

  /// How many rows the grid has.
  int get frames => bands <= 0 ? 0 : levels.length ~/ bands;

  /// How much of the track this analysis covers.
  Duration get span => frame * frames;

  @override
  double levelAt({required int band, required Duration position}) {
    if (bands <= 0 || frames == 0) return 0;

    final column = band.clamp(0, bands - 1);
    final at = position.inMicroseconds / frame.inMicroseconds;
    if (at <= 0) return _cell(0, column);

    final row = at.floor();
    // Past the end of the analysis the last row stands, which is what happens
    // when a file's tagged duration is longer than the sound in it. A track
    // that plays past its analysis is over, and the settle in the widget takes
    // the bars down.
    if (row >= frames - 1) return _cell(frames - 1, column);

    final from = _cell(row, column);
    final to = _cell(row + 1, column);

    return from + (to - from) * (at - row);
  }

  /// The grid and enough about it to read the grid back.
  Uint8List toBytes() {
    final bytes = Uint8List(_headerLength + levels.length);
    final header = ByteData.sublistView(bytes, 0, _headerLength);

    header.setUint32(0, _magic, Endian.little);
    header.setUint8(4, _version);
    header.setUint16(5, bands, Endian.little);
    header.setUint32(7, frame.inMicroseconds, Endian.little);
    bytes.setRange(_headerLength, bytes.length, levels);

    return bytes;
  }

  /// The level in [row] at [band], 0 to 1.
  double _cell(int row, int band) => levels[row * bands + band] / 255;
}

/// The stand-in envelope, synthesised from a track's identity.
///
/// **What this is, stated plainly:** not a measurement. It is a figure computed
/// from the track's path and the moment being played, and it is what the bars
/// show while [MeasuredEnergy] is being computed — a second or two on first
/// play, nothing at all afterwards because the analysis is cached — and for a
/// file the decoder could not read.
///
/// It is built to the two properties that make a stand-in honest:
///
/// - **Deterministic.** The same second of the same track draws the same bars
///   every time. It is a function of the seed and the position, and of nothing
///   else.
/// - **Distinct.** Two tracks seed differently and therefore move differently,
///   so it reads as belonging to what is playing rather than as the same loop
///   under everything.
///
/// The shape is three sine waves per band at unrelated rates — a slow swell, a
/// bar-length movement, and a fast flicker — under a tilt that keeps the low
/// bands heavier than the high ones, which is what every real spectrum does
/// and what makes the row read as a spectrum rather than as noise.
class SynthesisedEnergy extends TrackEnergy {
  /// Creates an envelope with [bands] bands, seeded by [seed].
  const SynthesisedEnergy({
    required this.seed,
    this.bands = TrackEnergy.defaultBands,
  });

  /// The stand-in for the track at [path].
  ///
  /// Seeded from the path, so a track keeps its own movement across runs and
  /// across machines — the same property `coverIdOf` gets from hashing bytes,
  /// for the same reason: nothing may depend on a hash Dart is free to change
  /// between releases.
  factory SynthesisedEnergy.forTrack(String path) {
    var hash = 0xcbf29ce484222325;
    for (final unit in path.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }

    return SynthesisedEnergy(seed: hash);
  }

  /// What seeds the movement.
  final int seed;

  @override
  final int bands;

  @override
  double levelAt({required int band, required Duration position}) {
    if (bands <= 0) return 0;

    final index = band.clamp(0, bands - 1);
    final seconds = position.inMilliseconds / 1000;

    // Three rates and three phases per band, all derived from the seed. The
    // rates are deliberately not multiples of each other: sines at related
    // rates re-align on a short cycle, and a bar that repeats every two
    // seconds reads as an animation rather than as a level.
    final slow = math.sin(
      seconds * _rate(index, 0, 0.45, 0.35) + _phase(index, 3),
    );
    final beat = math.sin(
      seconds * _rate(index, 1, 2.70, 1.30) + _phase(index, 5),
    );
    final flick = math.sin(
      seconds * _rate(index, 2, 7.10, 3.70) + _phase(index, 7),
    );

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
    var hash =
        seed ^ (band * 0x9E3779B97F4A7C15) ^ (component * 0x2545F4914F6CDD1D);
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
