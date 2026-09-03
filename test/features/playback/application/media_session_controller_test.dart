import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/application/audio_playback_controller.dart';
import 'package:orpheus/features/playback/application/media_session_controller.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:orpheus/features/playback/domain/media_session.dart';
import 'package:orpheus/features/playback/domain/playback_position_store.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// The media session: what a lock screen would be showing, and what pressing
/// its buttons does.
void main() {
  const names = MediaSessionNames(
    unknownTitle: 'Untitled',
    unknownArtist: 'Unknown artist',
    unknownAlbum: 'Unknown album',
  );

  final okComputer = [
    entry(
      id: 'ok1',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 1,
      coverId: 'sleeve-ok',
      duration: const Duration(minutes: 4, seconds: 44),
    ),
    entry(
      id: 'ok2',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 2,
      coverId: 'sleeve-ok',
    ),
  ];
  final untagged = [entry(id: 'nothing')];
  final library = [...okComputer, ...untagged];

  /// Everything running, with the words the session falls back to already
  /// supplied — which is what the shell does on its first build.
  Future<(AudioPlaybackController, MediaSessionController)> playerOf(
    Harness harness, {
    bool named = true,
  }) async {
    await harness.library();

    final session = harness.read(mediaSessionControllerProvider.notifier);
    if (named) session.remember(names);

    return (harness.read(audioPlaybackControllerProvider.notifier), session);
  }

  /// Lets every publish the last action started run to completion.
  ///
  /// Publishing reads the sleeve's location, which is asynchronous, so a test
  /// that asserted straight after pressing play would be asserting against the
  /// notification as it stood before the track reached it.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Reports [status] as the engine would, and lets the session hear it.
  Future<void> report(Harness harness, PlaybackStatus status) async {
    harness.player.report(status);
    await settle();
  }

  group('what it shows', () {
    test(
      'GivenATrackWithTags_WhenItIsPlayed_ThenTheSessionShowsThemRatherThanTheFileName',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);

        await player.playTrack(okComputer.first.file);
        await settle();

        final shown = harness.session.onScreen!;
        expect(shown.title, 'Airbag');
        expect(shown.artist, 'Radiohead');
        expect(shown.album, 'OK Computer');
        expect(shown.id, okComputer.first.file.path);
        // The name on disk is deliberately unlike the title, so a session that
        // fell back to it would say so here.
        expect(shown.title, isNot(contains('zzz')));
      },
    );

    test(
      'GivenAFileWhoseTagsNameNothing_WhenItIsPlayed_ThenTheSessionShowsTheUnknownWords',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);

        await player.playTrack(untagged.single.file);
        await settle();

        final shown = harness.session.onScreen!;
        expect(shown.title, 'Untitled');
        expect(shown.artist, 'Unknown artist');
        expect(shown.album, 'Unknown album');
      },
    );

    test(
      'GivenTheWordsHaveNotArrivedYet_WhenATrackIsPlayed_ThenNothingIsPublished',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness, named: false);

        await player.playTrack(okComputer.first.file);
        await settle();

        expect(harness.session.shown, isEmpty);
      },
    );

    test(
      'GivenATrackIsAlreadyPlaying_WhenTheLanguageChanges_ThenItIsPublishedAgainUnderTheNewWords',
      () async {
        final harness = Harness(library: library);
        final (player, session) = await playerOf(harness);
        await player.playTrack(untagged.single.file);
        await settle();

        session.remember(
          const MediaSessionNames(
            unknownTitle: 'Sem título',
            unknownArtist: 'Artista desconhecido',
            unknownAlbum: 'Álbum desconhecido',
          ),
        );
        await settle();

        expect(harness.session.onScreen!.title, 'Sem título');
      },
    );

    test(
      'GivenTheRecordHasASleeve_WhenItIsPlayed_ThenTheSessionIsGivenThePictureAsAPath',
      () async {
        final harness = Harness(library: library);
        harness.covers.locations['sleeve-ok'] = '/covers/sleeve-ok';
        final (player, _) = await playerOf(harness);

        await player.playTrack(okComputer.first.file);
        await settle();

        expect(harness.session.onScreen!.artPath, '/covers/sleeve-ok');
      },
    );

    test(
      'GivenTheRecordHasNoSleeve_WhenItIsPlayed_ThenTheSessionIsGivenNoPicture',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);

        await player.playTrack(untagged.single.file);
        await settle();

        expect(harness.session.onScreen!.artPath, isNull);
      },
    );

    test(
      'GivenTheEngineHasMeasuredTheTrack_WhenItReportsADuration_ThenThatIsShownRatherThanTheTag',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await settle();
        // The tag says 4:44; the file itself is a little longer.
        expect(harness.session.onScreen!.duration, const Duration(minutes: 4, seconds: 44));

        await report(
          harness,
          const PlaybackStatus(
            isPlaying: true,
            duration: Duration(minutes: 4, seconds: 47),
          ),
        );

        expect(
          harness.session.onScreen!.duration,
          const Duration(minutes: 4, seconds: 47),
        );
      },
    );

    test(
      'GivenAQueueOnItsLastTrackWithRepeatOff_WhenItIsShown_ThenTheNextButtonIsDead',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);

        await player.playTrack(okComputer.last.file);
        await settle();

        expect(harness.session.onScreen!.hasNext, isFalse);
      },
    );

    test(
      'GivenAQueueOnItsLastTrackSetToRepeat_WhenItIsShown_ThenTheNextButtonIsLive',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.cycleRepeat();
        await player.playTrack(okComputer.last.file);
        await settle();

        expect(harness.read(audioPlaybackControllerProvider).repeat, QueueRepeat.all);
        expect(harness.session.onScreen!.hasNext, isTrue);
      },
    );

    test(
      'GivenTheFirstTrackOfAQueue_WhenItIsShown_ThenThePreviousButtonIsStillLive',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);

        await player.playAlbum(okComputer.first.file);
        await settle();

        // Pressing back near the start steps out of the queue and pressing it
        // later restarts the track, so it never does nothing.
        expect(harness.session.onScreen!.hasPrevious, isTrue);
      },
    );

    test(
      'GivenNothingHasChanged_WhenTheEngineReportsTheSameStatusAgain_ThenNothingIsPublishedTwice',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        const status = PlaybackStatus(
          isPlaying: true,
          position: Duration(seconds: 30),
          duration: Duration(minutes: 4),
        );
        await report(harness, status);
        final published = harness.session.shown.length;

        await report(harness, status);

        expect(harness.session.shown.length, published);
      },
    );

    test(
      'GivenSomethingIsPlaying_WhenPlaybackIsStopped_ThenTheSessionIsTakenDown',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await settle();

        await player.stop();
        await settle();

        expect(harness.session.hides, 1);
        expect(harness.read(mediaSessionControllerProvider), isNull);
      },
    );

    test(
      'GivenTheOwnerIsBeingAskedWhereToResumeFrom_WhenTheOfferIsStanding_ThenNothingIsShown',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await harness.read(playbackPositionsProvider).record(
          PlaybackPosition(
            path: okComputer.first.file.path,
            position: const Duration(minutes: 2),
            updatedAt: DateTime.utc(2026),
          ),
        );

        await player.playTrack(okComputer.first.file);
        await settle();

        expect(
          harness.read(audioPlaybackControllerProvider).stage,
          AudioStage.offeringResume,
        );
        expect(harness.session.shown, isEmpty);
      },
    );

    test(
      'GivenNothingCouldBePlayed_WhenTheQueueGivesUp_ThenNothingIsShown',
      () async {
        final harness = Harness(
          library: library,
          missingTracks: {okComputer.first.file.path},
        );
        final (player, _) = await playerOf(harness);

        await player.playTrack(okComputer.first.file);
        await settle();

        expect(
          harness.read(audioPlaybackControllerProvider).stage,
          AudioStage.allFailed,
        );
        // The notification may have gone up as the track was opened — the
        // player says "starting" before it discovers the file is not there —
        // and what matters is that it came back down again.
        expect(harness.session.onScreen, isNull);
        expect(harness.session.hides, 1);
      },
    );
  });

  group('what its buttons do', () {
    test(
      'GivenATrackIsPlaying_WhenPauseIsPressedOnTheSession_ThenTheEngineIsPaused',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);

        harness.session.press(const PauseAsked());
        await settle();

        expect(harness.player.pauses, 1);
      },
    );

    test(
      'GivenPlaybackIsAlreadyPaused_WhenTheSystemAsksForAPause_ThenNothingStarts',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        harness.session.press(const PauseAsked());
        await settle();

        // A phone call arriving while playback is already paused asks for a
        // pause all the same. An unguarded toggle would answer it by starting
        // the music up into the middle of the call.
        harness.session.press(const PauseAsked());
        await settle();

        expect(harness.player.pauses, 1);
        expect(harness.player.plays, 0);
      },
    );

    test(
      'GivenPlaybackWasPaused_WhenResumeIsPressedOnTheSession_ThenTheEngineRuns',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        harness.session.press(const PauseAsked());
        await settle();

        harness.session.press(const ResumeAsked());
        await settle();

        expect(harness.player.plays, 1);
      },
    );

    test(
      'GivenPlaybackIsAlreadyRunning_WhenTheSystemHandsTheOutputBack_ThenNothingIsPausedByTheToggle',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);

        harness.session.press(const ResumeAsked());
        await settle();

        expect(harness.player.pauses, 0);
        expect(harness.player.plays, 0);
      },
    );

    test(
      'GivenAnAlbumIsPlaying_WhenNextIsPressedOnTheSession_ThenTheQueueMovesOn',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);

        harness.session.press(const NextAsked());
        await settle();

        expect(harness.player.opened.last, okComputer.last.file.path);
      },
    );

    test(
      'GivenPlaybackIsPastTheRestartThreshold_WhenPreviousIsPressedOnTheSession_ThenTheTrackStartsAgain',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playAlbum(okComputer.first.file);
        await report(
          harness,
          const PlaybackStatus(isPlaying: true, position: Duration(minutes: 2)),
        );

        harness.session.press(const PreviousAsked());
        await settle();

        expect(harness.player.seeks.last, Duration.zero);
      },
    );

    test(
      'GivenATrackIsPlaying_WhenTheSessionIsScrubbed_ThenPlaybackMovesThere',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);
        await report(
          harness,
          const PlaybackStatus(isPlaying: true, duration: Duration(minutes: 4)),
        );

        harness.session.press(const SeekAsked(Duration(minutes: 1)));
        await settle();

        expect(harness.player.seeks.last, const Duration(minutes: 1));
      },
    );

    test(
      'GivenATrackIsPlaying_WhenStopIsPressedOnTheSession_ThenTheQueueIsPutAway',
      () async {
        final harness = Harness(library: library);
        final (player, _) = await playerOf(harness);
        await player.playTrack(okComputer.first.file);

        harness.session.press(const StopAsked());
        await settle();

        expect(harness.player.stops, 1);
        expect(
          harness.read(audioPlaybackControllerProvider).stage,
          AudioStage.idle,
        );
      },
    );
  });
}
