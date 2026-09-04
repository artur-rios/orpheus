import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';

/// What the sound bars are drawn from.
///
/// Two things, and they are asserted for different reasons. [MeasuredEnergy]
/// is a grid read at a position, so what matters is that it lands on the right
/// row, reads between rows rather than stepping, and survives a trip through
/// the cache unchanged. [SynthesisedEnergy] is the stand-in, so what matters
/// is exactly the two properties that make a stand-in honest: it is the same
/// every time for the same track, and it is different between tracks.
void main() {
  group('MeasuredEnergy', () {
    /// A grid of [frames] rows whose every cell is the row number.
    MeasuredEnergy rising({required int frames, int bands = 2}) =>
        MeasuredEnergy(
          levels: Uint8List.fromList([
            for (var row = 0; row < frames; row++)
              for (var band = 0; band < bands; band++) row,
          ]),
          bands: bands,
          frame: const Duration(milliseconds: 100),
        );

    test(
      'GivenAnAnalysedTrack_WhenAMomentIsAskedFor_ThenTheRowCoveringItAnswers',
      () {
        final energy = rising(frames: 10);

        expect(
          energy.levelAt(band: 0, position: const Duration(milliseconds: 300)),
          closeTo(3 / 255, 0.0001),
        );
      },
    );

    test(
      'GivenAMomentBetweenTwoRows_WhenItIsAskedFor_ThenTheBarsReadBetweenThem',
      () {
        // Rows land about thirty times a second and the screen draws sixty:
        // stepping from row to row is visible, and reading between them is
        // what makes the bars move rather than tick.
        final energy = rising(frames: 10);

        expect(
          energy.levelAt(band: 0, position: const Duration(milliseconds: 350)),
          closeTo(3.5 / 255, 0.0001),
        );
      },
    );

    test('GivenAPositionPastTheEndOfTheAnalysis_WhenItIsAskedFor_ThenTheLastRowStands', () {
      // A file whose tag claims more than the sound in it, which is common
      // enough in a real library to be worth not crashing on.
      final energy = rising(frames: 4);

      expect(
        energy.levelAt(band: 0, position: const Duration(hours: 1)),
        closeTo(3 / 255, 0.0001),
      );
    });

    test('GivenAnAnalysis_WhenItIsWrittenToTheCacheAndReadBack_ThenItIsTheSameGrid', () {
      final energy = rising(frames: 6, bands: 3);

      final read = MeasuredEnergy.fromBytes(energy.toBytes());

      expect(read, isNotNull);
      expect(read!.bands, energy.bands);
      expect(read.frames, energy.frames);
      expect(read.frame, energy.frame);
      expect(read.levels, energy.levels);
    });

    test('GivenSomethingThatIsNotAnAnalysis_WhenItIsReadFromTheCache_ThenNothingComesBack', () {
      // A cache file from an older version, or one a disk truncated. Both
      // answer the same way: there is nothing here, analyse the track again.
      expect(MeasuredEnergy.fromBytes(Uint8List(4)), isNull);
      expect(
        MeasuredEnergy.fromBytes(Uint8List.fromList(List.filled(64, 7))),
        isNull,
      );
    });

    test('GivenABandOutsideTheAnalysis_WhenItIsRead_ThenItIsBroughtIntoRangeRatherThanThrowing', () {
      final energy = rising(frames: 4, bands: 3);

      expect(
        energy.levelAt(band: 999, position: Duration.zero),
        energy.levelAt(band: 2, position: Duration.zero),
      );
    });
  });

  group('SynthesisedEnergy', () {
    test('GivenTheSameTrackPlayedTwice_WhenTheSameSecondIsDrawn_ThenTheBarsStandAtTheSameHeights', () {
      final first = SynthesisedEnergy.forTrack('/music/airbag.flac');
      final second = SynthesisedEnergy.forTrack('/music/airbag.flac');

      for (var band = 0; band < first.bands; band++) {
        expect(
          first.levelAt(band: band, position: const Duration(seconds: 42)),
          second.levelAt(band: band, position: const Duration(seconds: 42)),
        );
      }
    });

    test(
      'GivenTwoDifferentTracks_WhenTheSameSecondIsDrawn_ThenTheyDoNotMoveAlike',
      () {
        final airbag = SynthesisedEnergy.forTrack('/music/airbag.flac');
        final karma = SynthesisedEnergy.forTrack('/music/karma.flac');

        final differences = [
          for (var band = 0; band < airbag.bands; band++)
            if (airbag.levelAt(
                  band: band,
                  position: const Duration(seconds: 9),
                ) !=
                karma.levelAt(band: band, position: const Duration(seconds: 9)))
              band,
        ];

        expect(differences, isNotEmpty);
      },
    );

    test('GivenAnyTrackAtAnyMoment_WhenABandIsRead_ThenItStandsWithinTheDrawableRange', () {
      // The painter multiplies this by half the widget's height; a level
      // outside 0 to 1 would draw outside the widget.
      final energy = SynthesisedEnergy.forTrack('/music/anything.mp3');

      for (var second = 0; second < 600; second += 7) {
        for (var band = 0; band < energy.bands; band++) {
          final level = energy.levelAt(
            band: band,
            position: Duration(seconds: second),
          );

          expect(level, inInclusiveRange(0, 1));
        }
      }
    });

    test('GivenAnEnvelope_WhenTheLowAndHighBandsAreCompared_ThenTheLowOnesCarryMoreOverTime', () {
      // Every real spectrum is heavier at the bottom, and an untilted row
      // reads as a hedge rather than as a level meter.
      final energy = SynthesisedEnergy.forTrack('/music/anything.mp3');

      var low = 0.0;
      var high = 0.0;
      for (var second = 0; second < 300; second++) {
        final at = Duration(seconds: second);
        low += energy.levelAt(band: 0, position: at);
        high += energy.levelAt(band: energy.bands - 1, position: at);
      }

      expect(low, greaterThan(high));
    });

    test('GivenABandOutsideTheEnvelope_WhenItIsRead_ThenItIsBroughtIntoRangeRatherThanThrowing', () {
      final energy = SynthesisedEnergy.forTrack('/music/anything.mp3');

      expect(
        energy.levelAt(band: 999, position: Duration.zero),
        energy.levelAt(band: energy.bands - 1, position: Duration.zero),
      );
    });
  });
}
