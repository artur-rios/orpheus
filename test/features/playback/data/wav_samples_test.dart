import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/data/wav_samples.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';
import 'package:path/path.dart' as p;

/// Reading back what the decoder wrote.
///
/// The decoder is libmpv writing a WAV file, which is not something a test can
/// run — so what is tested here is the other half of that seam: the two header
/// layouts mpv actually produces, the sample widths it produces them in, and
/// the whole path from a file on disk to a spectrum.
void main() {
  const rate = 16000;

  /// A WAV file of [seconds] of a sine at [hertz].
  ///
  /// [extensible] writes the `WAVE_FORMAT_EXTENSIBLE` header libmpv uses,
  /// which states its real format in a sub-format field rather than in the
  /// tag; the plain layout is what everything else writes.
  Uint8List wav(
    double hertz, {
    double seconds = 2,
    int channels = 1,
    int bits = 16,
    bool isFloat = false,
    bool extensible = false,
  }) {
    final frames = (rate * seconds).round();
    final width = bits ~/ 8;
    final block = channels * width;
    final data = ByteData(frames * block);

    for (var frame = 0; frame < frames; frame++) {
      final value = 0.8 * math.sin(2 * math.pi * hertz * frame / rate);
      for (var channel = 0; channel < channels; channel++) {
        final at = frame * block + channel * width;
        if (isFloat) {
          data.setFloat32(at, value, Endian.little);
        } else if (bits == 16) {
          data.setInt16(at, (value * 32767).round(), Endian.little);
        } else {
          data.setInt32(at, (value * 2147483647).round(), Endian.little);
        }
      }
    }

    final fmtLength = extensible ? 40 : 16;
    final head = ByteData(20 + fmtLength + 8);
    head.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
    head.setUint32(4, 12 + fmtLength + 8 + data.lengthInBytes, Endian.little);
    head.setUint32(8, 0x57415645, Endian.big); // 'WAVE'
    head.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
    head.setUint32(16, fmtLength, Endian.little);
    head.setUint16(20, extensible ? 0xFFFE : (isFloat ? 3 : 1), Endian.little);
    head.setUint16(22, channels, Endian.little);
    head.setUint32(24, rate, Endian.little);
    head.setUint32(28, rate * block, Endian.little);
    head.setUint16(32, block, Endian.little);
    head.setUint16(34, bits, Endian.little);

    if (extensible) {
      head.setUint16(36, 22, Endian.little);
      head.setUint16(38, bits, Endian.little);
      head.setUint32(40, channels == 1 ? 4 : 3, Endian.little);
      head.setUint16(44, isFloat ? 3 : 1, Endian.little);
    }

    head.setUint32(20 + fmtLength, 0x64617461, Endian.big); // 'data'
    head.setUint32(24 + fmtLength, data.lengthInBytes, Endian.little);

    return Uint8List.fromList([
      ...head.buffer.asUint8List(),
      ...data.buffer.asUint8List(),
    ]);
  }

  test('GivenAPlainWavHeader_WhenItIsRead_ThenItSaysWhatTheSamplesAre', () {
    final format = readWavFormat(wav(440, seconds: 0.1, channels: 2));

    expect(format, isNotNull);
    expect(format!.channels, 2);
    expect(format.sampleRate, rate);
    expect(format.bits, 16);
    expect(format.isFloat, isFalse);
    expect(format.frameLength, 4);
  });

  test('GivenTheExtensibleHeaderLibmpvWrites_WhenItIsRead_ThenTheSubFormatIsBelieved', () {
    // The tag says 0xFFFE, which means "look further down"; a reader that
    // stopped at the tag would read every float as a pair of integers.
    final format = readWavFormat(
      wav(440, seconds: 0.1, bits: 32, isFloat: true, extensible: true),
    );

    expect(format, isNotNull);
    expect(format!.isFloat, isTrue);
    expect(format.bits, 32);
  });

  test('GivenSomethingThatIsNotAWavFile_WhenItIsRead_ThenNothingComesBack', () {
    expect(readWavFormat(Uint8List(64)), isNull);
    expect(readWavFormat(Uint8List(8)), isNull);
  });

  group('analyseWavFile', () {
    late Directory scratch;

    setUp(() => scratch = Directory.systemTemp.createTempSync('orpheus-wav'));
    tearDown(() => scratch.deleteSync(recursive: true));

    /// Writes [bytes] into the scratch directory and answers the path.
    String written(Uint8List bytes) {
      final path = p.join(scratch.path, 'decoded.wav');
      File(path).writeAsBytesSync(bytes);

      return path;
    }

    /// Which band stands highest at [position].
    int loudestBand(MeasuredEnergy energy, Duration position) {
      var loudest = 0;
      for (var band = 1; band < energy.bands; band++) {
        if (energy.levelAt(band: band, position: position) >
            energy.levelAt(band: loudest, position: position)) {
          loudest = band;
        }
      }

      return loudest;
    }

    test('GivenADecodedFile_WhenItIsAnalysed_ThenTheBandCoveringItsPitchStandsHighest', () async {
      final low = await analyseWavFile(written(wav(220)));
      final high = await analyseWavFile(written(wav(3520)));

      expect(low, isNotNull);
      expect(high, isNotNull);

      const at = Duration(seconds: 1);
      expect(loudestBand(high!, at), greaterThan(loudestBand(low!, at)));
    });

    test(
      'GivenTheWidthsAndLayoutsMpvWrites_WhenTheyAreAnalysed_ThenTheyReadAlike',
      () async {
        const at = Duration(seconds: 1);

        final integers = await analyseWavFile(written(wav(1000)));
        final floats = await analyseWavFile(
          written(wav(1000, bits: 32, isFloat: true, extensible: true)),
        );
        final stereo = await analyseWavFile(written(wav(1000, channels: 2)));

        expect(loudestBand(floats!, at), loudestBand(integers!, at));
        expect(loudestBand(stereo!, at), loudestBand(integers, at));
      },
    );

    test('GivenAFileThatIsNotThere_WhenItIsAnalysed_ThenNothingComesBack', () {
      expect(
        analyseWavFile(p.join(scratch.path, 'gone.wav')),
        completion(isNull),
      );
    });

    test('GivenAFileThatIsNotAWav_WhenItIsAnalysed_ThenNothingComesBack', () {
      final path = p.join(scratch.path, 'not-a-wav');
      File(path).writeAsBytesSync(Uint8List.fromList(List.filled(9000, 3)));

      expect(analyseWavFile(path), completion(isNull));
    });
  });
}
