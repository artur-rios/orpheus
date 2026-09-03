import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';

/// The envelope the sound bars are drawn from.
///
/// It is synthesised rather than measured — nothing in this application
/// decodes audio — so what is worth asserting is exactly the two properties
/// that make a synthesised envelope honest: it is the same every time for the
/// same track, and it is different between tracks.
void main() {
  test(
    'GivenTheSameTrackPlayedTwice_WhenTheSameSecondIsDrawn_ThenTheBarsStandAtTheSameHeights',
    () {
      final first = TrackEnergy.forTrack('/music/airbag.flac');
      final second = TrackEnergy.forTrack('/music/airbag.flac');

      for (var band = 0; band < first.bands; band++) {
        expect(
          first.levelAt(band: band, position: const Duration(seconds: 42)),
          second.levelAt(band: band, position: const Duration(seconds: 42)),
        );
      }
    },
  );

  test(
    'GivenTwoDifferentTracks_WhenTheSameSecondIsDrawn_ThenTheyDoNotMoveAlike',
    () {
      final airbag = TrackEnergy.forTrack('/music/airbag.flac');
      final karma = TrackEnergy.forTrack('/music/karma.flac');

      final differences = [
        for (var band = 0; band < airbag.bands; band++)
          if (airbag.levelAt(band: band, position: const Duration(seconds: 9)) !=
              karma.levelAt(band: band, position: const Duration(seconds: 9)))
            band,
      ];

      expect(differences, isNotEmpty);
    },
  );

  test(
    'GivenAnyTrackAtAnyMoment_WhenABandIsRead_ThenItStandsWithinTheDrawableRange',
    () {
      // The painter multiplies this by half the widget's height; a level
      // outside 0 to 1 would draw outside the widget.
      final energy = TrackEnergy.forTrack('/music/anything.mp3');

      for (var second = 0; second < 600; second += 7) {
        for (var band = 0; band < energy.bands; band++) {
          final level = energy.levelAt(
            band: band,
            position: Duration(seconds: second),
          );

          expect(level, inInclusiveRange(0, 1));
        }
      }
    },
  );

  test(
    'GivenAnEnvelope_WhenTheLowAndHighBandsAreCompared_ThenTheLowOnesCarryMoreOverTime',
    () {
      // Every real spectrum is heavier at the bottom, and an untilted row
      // reads as a hedge rather than as a level meter.
      final energy = TrackEnergy.forTrack('/music/anything.mp3');

      var low = 0.0;
      var high = 0.0;
      for (var second = 0; second < 300; second++) {
        final at = Duration(seconds: second);
        low += energy.levelAt(band: 0, position: at);
        high += energy.levelAt(band: energy.bands - 1, position: at);
      }

      expect(low, greaterThan(high));
    },
  );

  test(
    'GivenABandOutsideTheEnvelope_WhenItIsRead_ThenItIsBroughtIntoRangeRatherThanThrowing',
    () {
      final energy = TrackEnergy.forTrack('/music/anything.mp3');

      expect(
        energy.levelAt(band: 999, position: Duration.zero),
        energy.levelAt(band: energy.bands - 1, position: Duration.zero),
      );
    },
  );
}
