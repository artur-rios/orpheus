import 'dart:math' as math;
import 'dart:typed_data';

import 'track_energy.dart';

/// Turns decoded audio into the grid the sound bars are drawn from.
///
/// This is the whole of the analysis, and it is deliberately ordinary: a
/// window of samples at a time, shaped and transformed, its bins gathered into
/// bands, the whole track levelled against its own loudest moment, and each
/// band given a fall so the row reads as a meter rather than as a flicker.
///
/// Fed rather than handed a track, because of the size of the thing being
/// analysed: an hour of mono audio is tens of megabytes of samples, and the
/// caller streams it past in blocks so that only one window is ever held.
///
/// Nothing here touches a file or a codec. It takes samples and answers a
/// [MeasuredEnergy], which is what makes it testable against a tone whose
/// spectrum is known in advance rather than only against a recording.
class SpectrumAnalyser {
  /// Creates an analyser for audio at [sampleRate].
  ///
  /// [window] must be a power of two. It and [hop] are what set the trade the
  /// analysis makes: a longer window separates two close notes better and
  /// smears a drum, and the defaults — 1024 samples, half of them new each
  /// time — are the usual compromise, about thirty rows a second at the rate
  /// the decoder is asked for.
  SpectrumAnalyser({
    required this.sampleRate,
    this.bands = TrackEnergy.defaultBands,
    this.window = 1024,
    this.hop = 512,
  }) : assert(sampleRate > 0, 'a sample rate is needed to place the bands'),
       assert(bands > 0, 'an analysis with no bands has nothing to show'),
       assert(window > 1 && window & (window - 1) == 0, 'window must be 2^n'),
       assert(window ~/ 2 > bands, 'a band needs a bin of its own'),
       assert(hop > 0 && hop <= window, 'the window must advance, and overlap'),
       _pending = Float64List(window),
       _real = Float64List(window),
       _imaginary = Float64List(window),
       _shape = _hann(window),
       _cosines = Float64List(window ~/ 2),
       _sines = Float64List(window ~/ 2) {
    for (var index = 0; index < window ~/ 2; index++) {
      final angle = -2 * math.pi * index / window;
      _cosines[index] = math.cos(angle);
      _sines[index] = math.sin(angle);
    }

    _edges = _bandEdges(bands: bands, window: window, sampleRate: sampleRate);
  }

  /// How loud the quietest visible sound is, under the track's own loudest.
  ///
  /// Fifty-five decibels: wide enough that the quiet passages of a record with
  /// any dynamic range left still move the bars, narrow enough that the noise
  /// floor of a rip does not.
  static const double _range = 55;

  /// How much of a band's level survives into the next row when the sound has
  /// gone.
  ///
  /// A meter that follows the spectrum exactly flickers, because the spectrum
  /// does. Peaks are kept and let down at this rate instead, which is what the
  /// needle on a real meter does and what the eye reads as loudness.
  static const double _fall = 0.72;

  /// The rate the samples fed in were decoded at.
  final int sampleRate;

  /// How many bands the grid carries.
  final int bands;

  /// How many samples each analysed window holds.
  final int window;

  /// How many new samples separate one window from the next.
  final int hop;

  final Float64List _pending;
  final Float64List _real;
  final Float64List _imaginary;
  final Float64List _shape;
  final Float64List _cosines;
  final Float64List _sines;
  final List<Float32List> _rows = [];

  late final List<int> _edges;
  int _filled = 0;

  /// How many rows have been analysed so far.
  int get rows => _rows.length;

  /// How much of the track one row covers.
  Duration get frame =>
      Duration(microseconds: (hop * 1000000 / sampleRate).round());

  /// Takes [samples] — mono, `-1` to `1` — as the next of the track.
  ///
  /// Blocks may be any length; a window is analysed whenever enough samples
  /// have arrived to fill one, and what is left over waits for the next block.
  void add(List<double> samples) {
    var offset = 0;

    while (offset < samples.length) {
      final take = math.min(window - _filled, samples.length - offset);
      for (var index = 0; index < take; index++) {
        _pending[_filled + index] = samples[offset + index];
      }

      _filled += take;
      offset += take;

      if (_filled < window) return;

      _rows.add(_analyse());
      // Slide by the hop: the tail of this window is the head of the next,
      // which is the overlap that keeps a drum from landing between two rows
      // and being softened by both.
      _pending.setRange(0, window - hop, _pending, hop);
      _filled = window - hop;
    }
  }

  /// The grid, or `null` when there was nothing to analyse.
  ///
  /// `null` covers the two cases that are the same answer to a caller: a file
  /// too short to fill a single window, and a file that is silent all the way
  /// through. Neither has a spectrum to show, and both fall back to the
  /// stand-in.
  MeasuredEnergy? finish() {
    if (_rows.isEmpty) return null;

    final reference = _reference();
    if (reference <= 0) return null;

    final levels = Uint8List(_rows.length * bands);
    final carried = Float64List(bands);

    for (var row = 0; row < _rows.length; row++) {
      for (var band = 0; band < bands; band++) {
        // Decibels against the track's own loudest moment rather than against
        // full scale: a quietly mastered record would otherwise draw a row of
        // stubs, and what an owner wants to see is this track's own shape.
        final amplitude = _rows[row][band];
        final level = amplitude <= 0
            ? 0.0
            : (1 + 20 * (math.log(amplitude / reference) / math.ln10) / _range)
                  .clamp(0.0, 1.0);

        final held = math.max(level, carried[band] * _fall);
        carried[band] = held;
        levels[row * bands + band] = (held * 255).round().clamp(0, 255);
      }
    }

    return MeasuredEnergy(levels: levels, bands: bands, frame: frame);
  }

  /// One window's worth of band amplitudes.
  Float32List _analyse() {
    for (var index = 0; index < window; index++) {
      _real[index] = _pending[index] * _shape[index];
      _imaginary[index] = 0;
    }

    _transform();

    final row = Float32List(bands);
    for (var band = 0; band < bands; band++) {
      final from = _edges[band];
      final to = _edges[band + 1];

      var power = 0.0;
      for (var bin = from; bin < to; bin++) {
        power += _real[bin] * _real[bin] + _imaginary[bin] * _imaginary[bin];
      }

      // The mean rather than the sum: the high bands span many more bins than
      // the low ones, and summing would make the top of the row tall for no
      // reason but the width of the band.
      row[band] = math.sqrt(power / (to - from));
    }

    return row;
  }

  /// The amplitude the whole track is levelled against.
  ///
  /// The 99th percentile rather than the maximum, so that one clipped sample
  /// or one cymbal does not push every other moment of the track down.
  double _reference() {
    final all = Float64List(_rows.length * bands);
    var count = 0;
    for (final row in _rows) {
      for (var band = 0; band < bands; band++) {
        all[count++] = row[band];
      }
    }

    final sorted = all.toList()..sort();

    return sorted[(sorted.length * 0.99).floor().clamp(0, sorted.length - 1)];
  }

  /// The transform, in place over [_real] and [_imaginary].
  ///
  /// Iterative Cooley-Tukey with the twiddle factors computed once in the
  /// constructor. Written out rather than taken from a package for the reason
  /// the tag reader and the hashes are: it has to give the same answer in an
  /// isolate, in a test, and on all three platforms, and it is forty lines.
  void _transform() {
    final count = window;

    for (var index = 1, mirror = 0; index < count; index++) {
      var bit = count >> 1;
      for (; mirror & bit != 0; bit >>= 1) {
        mirror ^= bit;
      }
      mirror ^= bit;

      if (index < mirror) {
        final real = _real[index];
        _real[index] = _real[mirror];
        _real[mirror] = real;

        final imaginary = _imaginary[index];
        _imaginary[index] = _imaginary[mirror];
        _imaginary[mirror] = imaginary;
      }
    }

    for (var length = 2; length <= count; length <<= 1) {
      final half = length >> 1;
      final step = count ~/ length;

      for (var start = 0; start < count; start += length) {
        for (var offset = 0; offset < half; offset++) {
          final twiddle = offset * step;
          final cosine = _cosines[twiddle];
          final sine = _sines[twiddle];

          final upper = start + offset + half;
          final realPart = _real[upper] * cosine - _imaginary[upper] * sine;
          final imaginaryPart =
              _real[upper] * sine + _imaginary[upper] * cosine;

          final lower = start + offset;
          _real[upper] = _real[lower] - realPart;
          _imaginary[upper] = _imaginary[lower] - imaginaryPart;
          _real[lower] += realPart;
          _imaginary[lower] += imaginaryPart;
        }
      }
    }
  }

  /// The Hann window of [length] points.
  ///
  /// A rectangular window would leak a pure tone across every band; this is
  /// the standard shape for the job and the one that makes the bands mean what
  /// they say.
  static Float64List _hann(int length) {
    final shape = Float64List(length);
    for (var index = 0; index < length; index++) {
      shape[index] = 0.5 * (1 - math.cos(2 * math.pi * index / (length - 1)));
    }

    return shape;
  }

  /// Where each band starts and the last one ends, as bin numbers.
  ///
  /// Spaced logarithmically between 40 Hz and 8 kHz, because that is how
  /// hearing is spaced: an even split would give thirteen of sixteen bands to
  /// sound above 2 kHz, where almost nothing on a record actually happens, and
  /// draw a row that barely moves.
  static List<int> _bandEdges({
    required int bands,
    required int window,
    required int sampleRate,
  }) {
    const lowest = 40.0;
    final highest = math.min(sampleRate / 2 * 0.98, 8000.0);
    final top = window ~/ 2;

    final edges = <int>[];
    var previous = 0;

    for (var band = 0; band <= bands; band++) {
      final frequency = lowest * math.pow(highest / lowest, band / bands);
      var bin = (frequency * window / sampleRate).round();

      // Every band has to hold at least one bin, and the top one has to stop
      // at the last: a band with no bins would divide by zero, and a band past
      // the end would read outside the transform. So each edge is pushed at
      // least one bin past the one before it, and held far enough below the
      // top that the bands still to come have a bin each.
      final ceiling = math.max(previous + 1, top - (bands - band));
      bin = bin.clamp(previous + 1, ceiling);
      edges.add(bin);
      previous = bin;
    }

    return edges;
  }
}
