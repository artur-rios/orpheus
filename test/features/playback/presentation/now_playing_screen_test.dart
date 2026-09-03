import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';
import 'package:orpheus/features/playback/presentation/now_playing_screen.dart';
import 'package:orpheus/features/playback/presentation/sound_bars.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The full player.
void main() {
  final library = [
    entry(
      id: '1',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 1,
    ),
    entry(
      id: '2',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 2,
    ),
  ];

  Future<Harness> playing(WidgetTester tester) async {
    final harness = Harness(library: library);
    await harness.library();
    await harness
        .read(audioPlaybackControllerProvider.notifier)
        .playAlbum(library.first.file);
    await tester.pumpHarness(harness, const NowPlayingScreen());

    return harness;
  }

  testWidgets(
    'GivenARecordIsPlaying_WhenThePlayerIsOpened_ThenTheTrackItsArtistAndItsRecordAreNamed',
    (tester) async {
      await playing(tester);

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('Radiohead'), findsOneWidget);
      expect(find.text('OK Computer'), findsWidgets);
    },
  );

  testWidgets(
    'GivenNothingIsPlaying_WhenThePlayerIsOpened_ThenItSaysSoRatherThanShowingAnEmptyFrame',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, const NowPlayingScreen());

      expect(find.text('Nothing is playing'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARecordIsPlaying_WhenThePlayerIsOpened_ThenTheBarsAreThere',
    (tester) async {
      await playing(tester);

      expect(find.byType(SoundBars), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATrackIsPlaying_WhenTheOwnerPressesPause_ThenTheEngineIsPaused',
    (tester) async {
      final harness = await playing(tester);
      harness.player.report(const PlaybackStatus(isPlaying: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_circle));
      await tester.pumpAndSettle();

      expect(harness.player.pauses, 1);
    },
  );

  testWidgets(
    'GivenAQueueWithATrackAfterThisOne_WhenTheOwnerPressesNext_ThenItOpens',
    (tester) async {
      final harness = await playing(tester);

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      expect(harness.player.opened.last, library[1].file.path);
    },
  );

  testWidgets(
    'GivenTheEngineKnowsHowLongTheTrackIs_WhenThePlayerIsOpened_ThenBothTimesAreShown',
    (tester) async {
      final harness = await playing(tester);

      harness.player.report(
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(minutes: 1, seconds: 5),
          duration: Duration(minutes: 4, seconds: 44),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01:05'), findsOneWidget);
      expect(find.text('04:44'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheEngineHasNotWorkedOutTheLength_WhenThePlayerIsOpened_ThenThereIsNothingToSeekInto',
    (tester) async {
      // A track with no duration has nothing to be a fraction of.
      await playing(tester);

      final slider = tester.widget<Slider>(find.byType(Slider).first);
      expect(slider.onChanged, isNull);
    },
  );

  testWidgets(
    'GivenRepeatIsOff_WhenTheOwnerPressesTheRepeatButton_ThenTheQueueRepeats',
    (tester) async {
      final harness = await playing(tester);

      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pumpAndSettle();

      expect(
        harness.read(audioPlaybackControllerProvider).repeat,
        QueueRepeat.all,
      );
    },
  );

  testWidgets(
    'GivenAPhoneSizedWindow_WhenThePlayerIsOpened_ThenTheVolumeSliderIsLeftToTheHardwareKeys',
    (tester) async {
      final harness = Harness(library: library);
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(library.first.file);

      await tester.pumpHarness(
        harness,
        const NowPlayingScreen(),
        window: phoneWindow,
      );

      // One slider — the progress bar — and no second one for the volume.
      expect(find.byType(Slider), findsOneWidget);
    },
  );
}
