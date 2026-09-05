import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';
import 'package:orpheus/features/playback/presentation/sound_bars.dart';

/// How the bars behave when the music does, and when the owner has asked the
/// system for less movement.
void main() {
  final energy = SynthesisedEnergy.forTrack('/library/zzz-1.flac');

  /// The instrument, playing or not, with [reduceMotion] as the system's
  /// setting.
  Widget bars({required bool isPlaying, required bool reduceMotion}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SoundBars(
              isPlaying: isPlaying,
              position: const Duration(seconds: 5),
              energy: energy,
            ),
          ),
        ),
      );

  /// How far the bars have risen toward what the envelope says, as drawn.
  double risen(WidgetTester tester) =>
      (tester.widget<CustomPaint>(
                find.descendant(
                  of: find.byType(SoundBars),
                  matching: find.byType(CustomPaint),
                ),
              ).painter!
              as SoundBarsPainter)
          .energyIn;

  /// Runs [frames] frames of the ticker.
  Future<void> run(WidgetTester tester, int frames) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets(
    'GivenTheMusicIsPlaying_WhenTheBarsAreDrawn_ThenTheyRise',
    (tester) async {
      await tester.pumpWidget(bars(isPlaying: true, reduceMotion: false));
      await run(tester, 10);

      expect(risen(tester), greaterThan(0));

      // Left resting, so the ticker is not still running at teardown.
      await tester.pumpWidget(bars(isPlaying: false, reduceMotion: false));
      await run(tester, 30);
    },
  );

  testWidgets(
    'GivenTheMusicIsPaused_WhenTheBarsAreDrawn_ThenTheyFallAwayRatherThanFreezing',
    (tester) async {
      // What an owner sees when they press pause is the sound falling away,
      // which is what pausing actually did.
      await tester.pumpWidget(bars(isPlaying: true, reduceMotion: false));
      await run(tester, 20);

      final playing = risen(tester);

      await tester.pumpWidget(bars(isPlaying: false, reduceMotion: false));
      await run(tester, 5);

      expect(risen(tester), lessThan(playing));

      await run(tester, 40);

      expect(risen(tester), 0);
    },
  );

  testWidgets(
    'GivenReducedMotionIsAskedFor_WhenTheMusicPlays_ThenTheBarsStandRatherThanMove',
    (tester) async {
      // Not the same thing more slowly: the bars stand at the levels of the
      // moment playback is at, and nothing moves.
      await tester.pumpWidget(bars(isPlaying: true, reduceMotion: true));
      await run(tester, 10);

      expect(risen(tester), 1);
    },
  );

  testWidgets(
    'GivenReducedMotionIsAskedFor_WhenNothingIsPlaying_ThenTheBarsAreDownRatherThanStanding',
    (tester) async {
      await tester.pumpWidget(bars(isPlaying: false, reduceMotion: true));
      await run(tester, 10);

      expect(risen(tester), 0);
    },
  );
}
