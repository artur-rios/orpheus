import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/domain/play_threshold.dart';

/// When a track counts as having been played.
void main() {
  test(
    'GivenATrackAbandonedBeforeHalfWay_WhenTheThresholdIsApplied_ThenItCountsNothing',
    () async {
      // Forty seconds of a two-minute song is not listening to it.
      expect(
        countsAsPlayed(
          position: const Duration(seconds: 40),
          duration: const Duration(minutes: 2),
        ),
        isFalse,
      );
    },
  );

  test(
    'GivenATrackHeardToHalfWay_WhenTheThresholdIsApplied_ThenItCounts',
    () async {
      expect(
        countsAsPlayed(
          position: const Duration(minutes: 1),
          duration: const Duration(minutes: 2),
        ),
        isTrue,
      );
    },
  );

  test(
    'GivenALongRecording_WhenFourMinutesHaveBeenHeard_ThenItCountsWithoutHalfOfIt',
    () async {
      // An hour-long live set does not stop counting because the owner left
      // before the encore.
      expect(
        countsAsPlayed(
          position: const Duration(minutes: 4),
          duration: const Duration(hours: 1),
        ),
        isTrue,
      );
    },
  );

  test(
    'GivenALongRecording_WhenLessThanFourMinutesHaveBeenHeard_ThenItCountsNothing',
    () async {
      expect(
        countsAsPlayed(
          position: const Duration(minutes: 3, seconds: 59),
          duration: const Duration(hours: 1),
        ),
        isFalse,
      );
    },
  );

  test(
    'GivenAVeryShortTrackHeardThrough_WhenTheThresholdIsApplied_ThenItCounts',
    () async {
      // A track heard to its end counts however short it is, which is the same
      // rule reached from the other side.
      expect(
        countsAsPlayed(
          position: const Duration(seconds: 20),
          duration: const Duration(seconds: 20),
        ),
        isTrue,
      );
    },
  );

  test(
    'GivenTheEngineHasNotReportedALength_WhenTheThresholdIsApplied_ThenItCountsNothing',
    () async {
      // With nothing to take half of, every version of this rule reduces to a
      // guess, and the next status carries the real duration a moment later.
      expect(
        countsAsPlayed(position: const Duration(minutes: 10), duration: null),
        isFalse,
      );
      expect(
        countsAsPlayed(
          position: const Duration(minutes: 10),
          duration: Duration.zero,
        ),
        isFalse,
      );
    },
  );

  test(
    'GivenNothingHasBeenHeard_WhenTheThresholdIsApplied_ThenItCountsNothing',
    () async {
      expect(
        countsAsPlayed(
          position: Duration.zero,
          duration: const Duration(minutes: 3),
        ),
        isFalse,
      );
    },
  );
}
