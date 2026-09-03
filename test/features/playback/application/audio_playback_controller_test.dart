import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/application/audio_playback_controller.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:orpheus/features/playback/domain/playback_position_store.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// The player: what it queues, what it skips, and what it remembers.
void main() {
  final okComputer = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohead', album: 'OK', track: 1),
    entry(id: 'ok2', title: 'Karma', artist: 'Radiohead', album: 'OK', track: 2),
    entry(id: 'ok3', title: 'Lucky', artist: 'Radiohead', album: 'OK', track: 3),
  ];
  final kidA = [
    entry(id: 'ka1', title: 'Idioteque', artist: 'Radiohead', album: 'Kid A', track: 1),
  ];
  final other = [
    entry(id: 'x1', title: 'So What', artist: 'Miles Davis', album: 'Blue', track: 1),
  ];
  final library = [...okComputer, ...kidA, ...other];

  Future<AudioPlaybackController> playerOf(Harness harness) async {
    // The library has to have loaded before a grouped queue can be gathered
    // from it, which is what every album and artist flow depends on.
    await harness.library();

    return harness.read(audioPlaybackControllerProvider.notifier);
  }

  AudioPlaybackState stateOf(Harness harness) =>
      harness.read(audioPlaybackControllerProvider);

  /// Reports [status] as the engine would, and lets the player hear it.
  ///
  /// The engine's stream is asynchronous, which is what it is in the real
  /// application too: a test that asserted straight after a report would be
  /// asserting against the state as it stood before the engine spoke.
  Future<void> report(Harness harness, PlaybackStatus status) async {
    harness.player.report(status);
    await Future<void>.delayed(Duration.zero);
  }

  group('playing one track', () {
    test(
      'GivenATrackWithNoStoredPosition_WhenItIsPlayed_ThenTheEngineOpensItFromTheStart',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.playTrack(okComputer.first.file);

        expect(harness.player.opened, [okComputer.first.file.path]);
        expect(harness.player.startedAt.single, Duration.zero);
        expect(stateOf(harness).stage, AudioStage.playing);
      },
    );

    test(
      'GivenATrackWithAStoredPosition_WhenItIsPlayed_ThenTheOwnerIsAskedBeforeAnythingOpens',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await harness.read(playbackPositionsProvider).record(
          PlaybackPosition(
            path: okComputer.first.file.path,
            position: const Duration(minutes: 2),
            updatedAt: DateTime.utc(2026),
          ),
        );

        await player.playTrack(okComputer.first.file);

        expect(stateOf(harness).stage, AudioStage.offeringResume);
        expect(stateOf(harness).resumeFrom, const Duration(minutes: 2));
        expect(harness.player.opened, isEmpty);
      },
    );

    test(
      'GivenTheOwnerIsOfferedAResume_WhenTheyContinue_ThenTheTrackOpensWhereItStopped',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await harness.read(playbackPositionsProvider).record(
          PlaybackPosition(
            path: okComputer.first.file.path,
            position: const Duration(minutes: 2),
            updatedAt: DateTime.utc(2026),
          ),
        );
        await player.playTrack(okComputer.first.file);

        await player.resume();

        expect(harness.player.startedAt.single, const Duration(minutes: 2));
      },
    );

    test(
      'GivenTheOwnerIsOfferedAResume_WhenTheyStartOver_ThenTheStoredPositionIsForgotten',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        final positions = harness.read(playbackPositionsProvider);
        await positions.record(
          PlaybackPosition(
            path: okComputer.first.file.path,
            position: const Duration(minutes: 2),
            updatedAt: DateTime.utc(2026),
          ),
        );
        await player.playTrack(okComputer.first.file);

        await player.startOver();

        expect(harness.player.startedAt.single, Duration.zero);
        expect(positions.positionFor(okComputer.first.file.path), isNull);
      },
    );
  });

  group('playing a record', () {
    test(
      'GivenARecordStartedFromItsThirdTrack_WhenItIsPlayed_ThenTheWholeRecordIsQueuedFromThere',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.playAlbum(okComputer[2].file);

        final queue = stateOf(harness).queue;
        expect(queue.tracks.length, 3);
        expect(queue.index, 2);
        expect(queue.kind, QueueKind.album);
        expect(queue.label, 'OK');
        expect(harness.player.opened, [okComputer[2].file.path]);
      },
    );

    test(
      'GivenARecordIsShuffled_WhenItIsPlayed_ThenTheSameTracksAreQueuedStartingAtTheTop',
      () async {
        // Starting a shuffle at the track the owner happened to click would
        // make the first track the one predictable thing about it.
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.playAlbum(okComputer[2].file, shuffled: true);

        final queue = stateOf(harness).queue;
        expect(queue.index, 0);
        expect(
          {for (final file in queue.tracks) file.path},
          {for (final e in okComputer) e.file.path},
        );
      },
    );

    test(
      'GivenAnArtistWithTwoRecords_WhenTheArtistIsPlayed_ThenEveryTrackOfBothIsQueued',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.playArtist(okComputer.first.file);

        final queue = stateOf(harness).queue;
        expect(queue.tracks.length, 4);
        expect(queue.kind, QueueKind.artist);
        expect(queue.label, 'Radiohead');
      },
    );

    test(
      'GivenAWholeLibrary_WhenEverythingIsShuffled_ThenEveryTrackIsQueuedUnderTheGivenName',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.playEverythingShuffled(label: 'Everything, shuffled');

        final queue = stateOf(harness).queue;
        expect(queue.tracks.length, library.length);
        expect(queue.kind, QueueKind.playlist);
        expect(queue.label, 'Everything, shuffled');
      },
    );
  });

  group('files that will not play', () {
    test(
      'GivenTheFirstTrackOfARecordIsGone_WhenTheRecordIsPlayed_ThenItIsNamedAndTheNextOneOpens',
      () async {
        final harness = Harness(
          library: library,
          missingTracks: {okComputer.first.file.path},
        );
        final player = await playerOf(harness);

        await player.playAlbum(okComputer.first.file);

        expect(harness.player.opened, [okComputer[1].file.path]);
        expect(stateOf(harness).lastSkipped?.path, okComputer.first.file.path);
        expect(stateOf(harness).stage, AudioStage.playing);
      },
    );

    test(
      'GivenEveryTrackOfARecordIsGone_WhenItIsPlayed_ThenTheQueueIsClearedAndTheOwnerIsTold',
      () async {
        final harness = Harness(
          library: library,
          missingTracks: {for (final e in okComputer) e.file.path},
        );
        final player = await playerOf(harness);

        await player.playAlbum(okComputer.first.file);

        expect(stateOf(harness).stage, AudioStage.allFailed);
        expect(stateOf(harness).queue.isEmpty, isTrue);
        expect(harness.player.opened, isEmpty);
      },
    );

    test(
      'GivenTheOwnerHasReadTheSkipNotice_WhenTheyDismissIt_ThenItIsGone',
      () async {
        final harness = Harness(
          library: library,
          missingTracks: {okComputer.first.file.path},
        );
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        player.acknowledgeSkip();

        expect(stateOf(harness).lastSkipped, isNull);
      },
    );

    test(
      'GivenTheEngineCannotDecodeTheOpenTrack_WhenItSaysSo_ThenTheQueueStepsPastIt',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        await report(harness, const PlaybackStatus(failedToDecode: true));

        expect(harness.player.opened.last, okComputer[1].file.path);
        expect(stateOf(harness).lastSkipped?.path, okComputer.first.file.path);
      },
    );
  });

  group('moving through a queue', () {
    test(
      'GivenATrackPlaysToItsEnd_WhenTheEngineSaysSo_ThenTheNextTrackOpens',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        await report(harness, const PlaybackStatus(hasEnded: true));

        expect(harness.player.opened.last, okComputer[1].file.path);
      },
    );

    test(
      'GivenTheLastTrackOfAQueuePlaysToItsEnd_WhenTheEngineSaysSo_ThenThePlayerGoesIdle',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playTrack(other.first.file);

        await report(harness, const PlaybackStatus(hasEnded: true));

        expect(stateOf(harness).stage, AudioStage.idle);
      },
    );

    test(
      'GivenRepeatIsSetToOne_WhenTheTrackEnds_ThenTheSameTrackOpensAgain',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);
        await player.cycleRepeat();
        await player.cycleRepeat();
        expect(stateOf(harness).repeat, QueueRepeat.one);

        await report(harness, const PlaybackStatus(hasEnded: true));

        expect(harness.player.opened.last, okComputer.first.file.path);
      },
    );

    test(
      'GivenRepeatIsSetToAll_WhenTheLastTrackEnds_ThenTheQueueStartsAgain',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer[2].file);
        await player.cycleRepeat();
        expect(stateOf(harness).repeat, QueueRepeat.all);

        await report(harness, const PlaybackStatus(hasEnded: true));

        expect(harness.player.opened.last, okComputer.first.file.path);
      },
    );

    test(
      'GivenPlaybackIsSecondsIntoATrack_WhenTheOwnerPressesBack_ThenThePreviousTrackOpens',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer[1].file);
        await report(harness, const PlaybackStatus(isPlaying: true, position: Duration(seconds: 2)));

        await player.previous();

        expect(harness.player.opened.last, okComputer.first.file.path);
      },
    );

    test(
      'GivenPlaybackIsWellIntoATrack_WhenTheOwnerPressesBack_ThenThatTrackStartsAgain',
      () async {
        // What every physical player has done: back near the start goes to the
        // previous song, and back in the middle restarts this one.
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer[1].file);
        await report(harness, const PlaybackStatus( isPlaying: true, position: Duration(minutes: 2), duration: Duration(minutes: 4), ));

        await player.previous();

        expect(harness.player.opened.length, 1);
        expect(harness.player.seeks.last, Duration.zero);
      },
    );

    test(
      'GivenAQueueOnScreen_WhenARowIsTapped_ThenThatTrackOpens',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        await player.jumpTo(2);

        expect(harness.player.opened.last, okComputer[2].file.path);
      },
    );

    test(
      'GivenAQueueOnScreen_WhenARowOutsideItIsAskedFor_ThenNothingOpens',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);
        final opened = harness.player.opened.length;

        await player.jumpTo(99);

        expect(harness.player.opened.length, opened);
      },
    );
  });

  group('seeking, pausing and stopping', () {
    test(
      'GivenASeekPastTheEndOfTheTrack_WhenItIsAskedFor_ThenItIsBoundedToTheDuration',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await report(harness, const PlaybackStatus(isPlaying: true, duration: Duration(minutes: 4)));

        await player.seekTo(const Duration(hours: 1));

        expect(harness.player.seeks.last, const Duration(minutes: 4));
      },
    );

    test(
      'GivenTrackIsPlaying_WhenTheOwnerPausesAndResumes_ThenTheEngineIsToldBoth',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await report(harness, const PlaybackStatus(isPlaying: true));

        await player.togglePlaying();
        await report(harness, const PlaybackStatus());
        await player.togglePlaying();

        expect(harness.player.pauses, 1);
        expect(harness.player.plays, 1);
      },
    );

    test(
      'GivenSomethingIsPlaying_WhenTheOwnerStops_ThenTheQueueIsClearedAndTheEngineReleased',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        await player.stop();

        expect(harness.player.stops, 1);
        expect(stateOf(harness).stage, AudioStage.idle);
        expect(stateOf(harness).queue.isEmpty, isTrue);
      },
    );

    test(
      'GivenPlaybackHasReachedTheMiddleOfATrack_WhenItIsPaused_ThenTheResumePointIsWritten',
      () async {
        final harness = Harness(library: library, now: DateTime.utc(2026, 5));
        final player = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await report(harness, const PlaybackStatus( isPlaying: true, position: Duration(minutes: 1), duration: Duration(minutes: 4), ));

        await player.togglePlaying();

        expect(
          harness
              .read(playbackPositionsProvider)
              .positionFor(okComputer.first.file.path)
              ?.position,
          const Duration(minutes: 1),
        );
      },
    );

    test(
      'GivenATrackPlaysToItsEnd_WhenTheEngineSaysSo_ThenItsResumePointIsForgotten',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);
        final positions = harness.read(playbackPositionsProvider);
        await player.playTrack(other.first.file);
        await positions.record(
          PlaybackPosition(
            path: other.first.file.path,
            position: const Duration(minutes: 1),
            updatedAt: DateTime.utc(2026),
          ),
        );

        await report(harness, const PlaybackStatus(hasEnded: true));

        expect(positions.positionFor(other.first.file.path), isNull);
      },
    );
  });

  group('volume', () {
    test(
      'GivenTheOwnerSetsAVolume_WhenATrackIsPlayed_ThenTheEngineIsOpenedAtThatLevel',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.setVolume(0.4);
        await player.playTrack(okComputer.first.file);

        expect(harness.player.volumes, contains(0.4));
        expect(harness.settings.volume, 0.4);
      },
    );

    test(
      'GivenAVolumeOutsideTheRange_WhenItIsSet_ThenItIsBroughtIntoIt',
      () async {
        final harness = Harness(library: library);
        final player = await playerOf(harness);

        await player.setVolume(4);

        expect(harness.player.volumes.last, 1.0);
      },
    );
  });
}
