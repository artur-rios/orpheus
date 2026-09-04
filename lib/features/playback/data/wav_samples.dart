import 'dart:io';
import 'dart:typed_data';

import '../domain/audio_spectrum.dart';
import '../domain/track_energy.dart';

/// What the header of a WAV file says about the samples behind it.
class WavFormat {
  /// Creates a description of a stream.
  const WavFormat({
    required this.channels,
    required this.sampleRate,
    required this.bits,
    required this.isFloat,
    required this.dataOffset,
    required this.dataLength,
  });

  /// How many channels are interleaved.
  final int channels;

  /// How many frames a second the stream carries.
  final int sampleRate;

  /// How wide one sample is.
  final int bits;

  /// Whether samples are floating point rather than signed integers.
  final bool isFloat;

  /// Where the samples start in the file.
  final int dataOffset;

  /// How many bytes of samples the header claims, or `-1` for "to the end".
  final int dataLength;

  /// How many bytes one frame — one sample of every channel — takes.
  int get frameLength => channels * (bits ~/ 8);
}

/// Reads [bytes] as the head of a WAV file, or answers `null` for anything
/// this cannot play back as samples.
///
/// Written out rather than taken from a package because of how narrow the job
/// is: the only WAV files this reads are the ones the decoder wrote a moment
/// earlier, and what a general reader would add is support for files that
/// never arrive here.
WavFormat? readWavFormat(Uint8List bytes) {
  if (bytes.length < 44) return null;

  final head = ByteData.sublistView(bytes);
  if (head.getUint32(0, Endian.big) != 0x52494646) return null; // 'RIFF'
  if (head.getUint32(8, Endian.big) != 0x57415645) return null; // 'WAVE'

  var offset = 12;
  int? channels;
  int? sampleRate;
  int? bits;
  var isFloat = false;

  while (offset + 8 <= bytes.length) {
    final id = head.getUint32(offset, Endian.big);
    final length = head.getUint32(offset + 4, Endian.little);
    final body = offset + 8;

    if (id == 0x666d7420 && body + 16 <= bytes.length) {
      // 'fmt '
      var tag = head.getUint16(body, Endian.little);
      channels = head.getUint16(body + 2, Endian.little);
      sampleRate = head.getUint32(body + 4, Endian.little);
      bits = head.getUint16(body + 14, Endian.little);

      // The extensible layout, which is what libmpv writes: the real format
      // is the first two bytes of the sub-format that follows the extension.
      if (tag == 0xFFFE && body + 26 <= bytes.length) {
        tag = head.getUint16(body + 24, Endian.little);
      }

      if (tag != 1 && tag != 3) return null;
      isFloat = tag == 3;
    }

    if (id == 0x64617461) {
      // 'data'
      if (channels == null || sampleRate == null || bits == null) return null;
      if (channels <= 0 || sampleRate <= 0 || bits % 8 != 0) return null;
      if (isFloat ? bits != 32 && bits != 64 : bits < 8 || bits > 32) {
        return null;
      }

      return WavFormat(
        channels: channels,
        sampleRate: sampleRate,
        bits: bits,
        isFloat: isFloat,
        dataOffset: body,
        // A length that runs past the end of the file is a header that was
        // never patched, which is what a decoder that was killed mid-write
        // leaves behind. Read to the end instead of trusting it.
        dataLength: length <= 0 ? -1 : length,
      );
    }

    // Chunks are padded to an even length, and a chunk claiming to be no
    // length at all would walk this loop forever.
    offset = body + length + (length.isOdd ? 1 : 0);
    if (length <= 0) return null;
  }

  return null;
}

/// Converts [bytes] — whole frames of [format] — into mono samples, `-1` to
/// `1`, appended to [into].
///
/// Channels are averaged rather than one of them taken: a record with the
/// bass panned to one side would otherwise be analysed as half of itself.
void readWavSamples(Uint8List bytes, WavFormat format, List<double> into) {
  final view = ByteData.sublistView(bytes);
  final width = format.bits ~/ 8;
  final frames = bytes.length ~/ format.frameLength;

  for (var frame = 0; frame < frames; frame++) {
    var total = 0.0;

    for (var channel = 0; channel < format.channels; channel++) {
      final at = frame * format.frameLength + channel * width;
      total += _sampleAt(view, at, format);
    }

    into.add(total / format.channels);
  }
}

/// The spectrum of the WAV file at [path], or `null` where it has none.
///
/// Streamed a block at a time rather than read whole: an hour-long file is
/// over a hundred megabytes of samples at the rate the decoder is asked for,
/// and none of it needs to be held once its window has been transformed.
Future<MeasuredEnergy?> analyseWavFile(
  String path, {
  int bands = TrackEnergy.defaultBands,
}) async {
  final file = File(path);
  if (!file.existsSync()) return null;

  final handle = await file.open();
  try {
    final head = await handle.read(4096);
    final format = readWavFormat(head);
    if (format == null) return null;

    final analyser = SpectrumAnalyser(
      sampleRate: format.sampleRate,
      bands: bands,
    );

    // Whole frames per block, so that a sample is never split across two
    // reads and every block starts on a channel boundary.
    final block = (65536 ~/ format.frameLength) * format.frameLength;
    if (block <= 0) return null;

    var read = 0;
    final remaining = format.dataLength;
    await handle.setPosition(format.dataOffset);

    while (remaining < 0 || read < remaining) {
      final want = remaining < 0 ? block : _min(block, remaining - read);
      final bytes = await handle.read(want);
      if (bytes.length < format.frameLength) break;

      final whole = Uint8List.sublistView(
        bytes,
        0,
        bytes.length - bytes.length % format.frameLength,
      );

      final samples = <double>[];
      readWavSamples(whole, format, samples);
      analyser.add(samples);
      read += bytes.length;
    }

    return analyser.finish();
  } finally {
    await handle.close();
  }
}

/// One sample at [at], as a number between `-1` and `1`.
double _sampleAt(ByteData view, int at, WavFormat format) {
  if (format.isFloat) {
    return format.bits == 64
        ? view.getFloat64(at, Endian.little)
        : view.getFloat32(at, Endian.little);
  }

  switch (format.bits) {
    case 8:
      // Eight-bit WAV is the one integer width that is unsigned.
      return (view.getUint8(at) - 128) / 128;
    case 16:
      return view.getInt16(at, Endian.little) / 32768;
    case 24:
      final low = view.getUint8(at);
      final middle = view.getUint8(at + 1);
      final high = view.getInt8(at + 2);

      return ((high << 16) | (middle << 8) | low) / 8388608;
    default:
      return view.getInt32(at, Endian.little) / 2147483648;
  }
}

/// The smaller of [a] and [b].
int _min(int a, int b) => a < b ? a : b;
