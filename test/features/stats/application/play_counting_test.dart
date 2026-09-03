import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/application/audio_playback_controller.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// The player deciding that a play happened.
///
/// The threshold itself is tested in `domain/play_threshold_test.dart`; this
/// is about the player applying it — once per playthrough, and again for the
/// next one.
void main() {
  final okComputer = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: 'ok2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer'),
  ];

  Future<AudioPlaybackController> playerOf(Harness harness) async {
    await harness.library();

    return harness.read(audioPlaybackControllerProvider.notifier);
  }

  /// Reports [status] as the engine would, and lets the player act on it.
  Future<void> report(Harness harness, PlaybackStatus status) async {
    harness.player.report(status);
    await Future<void>.delayed(Duration.zero);
  }

  /// Past the threshold of a four-minute track.
  const halfWay = PlaybackStatus(
    isPlaying: true,
    position: Duration(minutes: 2),
    duration: Duration(minutes: 4),
  );

  /// What the history holds for [path].
  int playsOf(Harness harness, String path) =>
      harness.plays.history.tracks[path]?.plays ?? 0;

  test(
    'GivenATrackSkippedEarly_WhenItIsAbandoned_ThenNoPlayIsCounted',
    () async {
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.playTrack(okComputer.first.file);

      await report(
        harness,
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(seconds: 20),
          duration: Duration(minutes: 4),
        ),
      );

      expect(harness.plays.history.totalPlays, 0);
    },
  );

  test(
    'GivenATrackHeardToHalfWay_WhenTheThresholdIsPassed_ThenOnePlayIsCounted',
    () async {
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.playTrack(okComputer.first.file);

      await report(
        harness,
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(minutes: 2),
          duration: Duration(minutes: 4),
        ),
      );

      expect(playsOf(harness, okComputer.first.file.path), 1);
    },
  );

  test(
    'GivenTheThresholdWasAlreadyPassed_WhenTheRestOfTheTrackPlays_ThenItIsNotCountedAgain',
    () async {
      // The status stream reports several times a second, and every report
      // after the first is also past the threshold.
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.playTrack(okComputer.first.file);

      for (final second in [120, 150, 180, 210]) {
        await report(
          harness,
          PlaybackStatus(
            isPlaying: true,
            position: Duration(seconds: second),
            duration: const Duration(minutes: 4),
          ),
        );
      }

      expect(playsOf(harness, okComputer.first.file.path), 1);
    },
  );

  test(
    'GivenASongLeftOnRepeat_WhenItComesRoundAgain_ThenEachPlaythroughIsCounted',
    () async {
      // The reason the flag is cleared when a track *opens* rather than when
      // the current track changes: keyed to the change, a song on repeat would
      // be worth one play a session.
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.cycleRepeat(); // all
      await player.cycleRepeat(); // one
      await player.playTrack(okComputer.first.file);

      await report(harness, halfWay);
      // The track finishes, and repeat-one opens it again.
      await report(
        harness,
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(minutes: 4),
          duration: Duration(minutes: 4),
          hasEnded: true,
        ),
      );
      await report(harness, halfWay);

      expect(playsOf(harness, okComputer.first.file.path), 2);
    },
  );

  test(
    'GivenATrackWithAResumePointPlayedAgain_WhenTheOwnerStartsItOver_ThenASecondPlayIsCounted',
    () async {
      // Putting the same record on again is a second playthrough and a second
      // play — the listening the statistics exist to count.
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);

      await player.playTrack(okComputer.first.file);
      await report(harness, halfWay);

      // Half a track played leaves a resume point, so playing it again asks
      // where to start; starting it over is a fresh playthrough.
      await player.playTrack(okComputer.first.file);
      await player.startOver();
      await report(harness, halfWay);

      expect(playsOf(harness, okComputer.first.file.path), 2);
    },
  );

  test(
    'GivenAVeryShortTrack_WhenItReachesItsEnd_ThenItIsCountedEvenWithNoStatusInBetween',
    () async {
      // A track short enough that no ordinary status landed past its half-way
      // point would otherwise be the one kind of track that never counted,
      // however often it was played.
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.playTrack(okComputer.first.file);

      await report(
        harness,
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(seconds: 12),
          duration: Duration(seconds: 12),
          hasEnded: true,
        ),
      );

      expect(playsOf(harness, okComputer.first.file.path), 1);
    },
  );

  test(
    'GivenTheEngineHasNotReportedALength_WhenPlaybackRuns_ThenNothingIsCountedYet',
    () async {
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);
      await player.playTrack(okComputer.first.file);

      await report(
        harness,
        const PlaybackStatus(isPlaying: true, position: Duration(minutes: 9)),
      );

      expect(harness.plays.history.totalPlays, 0);
    },
  );

  test(
    'GivenAnAlbumPlaying_WhenTheQueueMovesToTheNextTrack_ThenEachTrackIsCountedOnItsOwn',
    () async {
      final harness = Harness(library: okComputer);
      final player = await playerOf(harness);

      await player.playAlbum(okComputer.first.file);
      await report(harness, halfWay);
      await player.next();
      await report(harness, halfWay);

      expect(playsOf(harness, okComputer.first.file.path), 1);
      expect(playsOf(harness, okComputer.last.file.path), 1);
    },
  );
}
