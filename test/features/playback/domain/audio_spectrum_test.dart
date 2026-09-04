import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/audio_spectrum.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';

/// The analysis the sound bars are drawn from.
///
/// This is the one piece of the feature that can be checked against an answer
/// known in advance rather than against a recording: a tone at a stated pitch
/// has to raise the band that covers that pitch and not another, and a higher
/// tone has to raise a higher band. If those hold, the bars are showing the
/// sound; if they do not, no amount of the row moving means anything.
void main() {
  const rate = 16000;

  /// [seconds] of a sine wave at [hertz], as the decoder would deliver it.
  List<double> tone(double hertz, {double seconds = 2, double gain = 0.8}) => [
    for (var sample = 0; sample < (rate * seconds).round(); sample++)
      gain * math.sin(2 * math.pi * hertz * sample / rate),
  ];

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

  test('GivenAToneAtOneKilohertz_WhenItIsAnalysed_ThenOneBandStandsWellAboveTheRest', () {
    final analyser = SpectrumAnalyser(sampleRate: rate)..add(tone(1000));

    final energy = analyser.finish();

    expect(energy, isNotNull);
    const at = Duration(seconds: 1);
    final loudest = loudestBand(energy!, at);

    expect(energy.levelAt(band: loudest, position: at), greaterThan(0.9));
    for (var band = 0; band < energy.bands; band++) {
      if ((band - loudest).abs() <= 1) continue;
      expect(
        energy.levelAt(band: band, position: at),
        lessThan(0.5),
        reason: 'band $band should be quiet under a 1 kHz tone',
      );
    }
  });

  test('GivenTwoTonesAnOctaveApart_WhenTheyAreAnalysed_ThenTheHigherOneRaisesAHigherBand', () {
    // The point of the whole exercise: the row is a spectrum, so where it
    // rises has to follow what is actually in the sound.
    final low = (SpectrumAnalyser(sampleRate: rate)..add(tone(220))).finish();
    final high = (SpectrumAnalyser(sampleRate: rate)..add(tone(3520))).finish();

    expect(low, isNotNull);
    expect(high, isNotNull);

    const at = Duration(seconds: 1);
    expect(loudestBand(high!, at), greaterThan(loudestBand(low!, at)));
  });

  test('GivenATrackThatGrowsLouder_WhenItIsAnalysed_ThenTheBarsAreLowerAtTheStartThanAtTheEnd', () {
    final samples = <double>[];
    for (var sample = 0; sample < rate * 4; sample++) {
      final into = sample / (rate * 4);
      samples.add(into * math.sin(2 * math.pi * 440 * sample / rate));
    }

    final energy = (SpectrumAnalyser(sampleRate: rate)..add(samples)).finish();

    expect(energy, isNotNull);
    final band = loudestBand(energy!, const Duration(seconds: 3));

    expect(
      energy.levelAt(band: band, position: const Duration(milliseconds: 200)),
      lessThan(
        energy.levelAt(band: band, position: const Duration(seconds: 3)),
      ),
    );
  });

  test('GivenSilence_WhenItIsAnalysed_ThenThereIsNothingToShow', () {
    // A silent file has no spectrum, and the answer that says so is what makes
    // the bars fall back to the stand-in rather than draw a flat row.
    final analyser = SpectrumAnalyser(sampleRate: rate)
      ..add(List.filled(rate * 2, 0));

    expect(analyser.finish(), isNull);
  });

  test('GivenAudioTooShortToFillOneWindow_WhenItIsAnalysed_ThenThereIsNothingToShow', () {
    final analyser = SpectrumAnalyser(sampleRate: rate)
      ..add(tone(440, seconds: 0.01));

    expect(analyser.rows, 0);
    expect(analyser.finish(), isNull);
  });

  test(
    'GivenAudioFedInUnevenBlocks_WhenItIsAnalysed_ThenItReadsTheSameAsOneBlock',
    () {
      // The decoder hands over whatever a read gave it, which is not a whole
      // number of windows and not the same length twice.
      final samples = tone(1000);

      final whole = (SpectrumAnalyser(sampleRate: rate)..add(samples)).finish();

      final pieces = SpectrumAnalyser(sampleRate: rate);
      for (var at = 0; at < samples.length; at += 777) {
        pieces.add(samples.sublist(at, math.min(at + 777, samples.length)));
      }

      expect(pieces.finish()!.levels, whole!.levels);
    },
  );

  test('GivenAnAnalysis_WhenItsRowsAreCounted_ThenTheyLandAtTheHopRate', () {
    final analyser = SpectrumAnalyser(sampleRate: rate)..add(tone(440));

    // 512 samples at 16 kHz: thirty-two milliseconds, about thirty-one rows a
    // second, which is what the widget reads between.
    expect(analyser.frame, const Duration(milliseconds: 32));
    expect(analyser.rows, greaterThan(60));
  });
}
