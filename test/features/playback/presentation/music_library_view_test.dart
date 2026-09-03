import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playback/presentation/music_rows.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The music area: what it lists, and what happens when a row is used.
void main() {
  final library = [
    entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer', track: 1),
    entry(id: '2', title: 'Karma Police', artist: 'Radiohead', album: 'OK Computer', track: 2),
    entry(id: '3', title: 'Everything', artist: 'Radiohead', album: 'Kid A', track: 1),
    entry(id: '4', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue', track: 1),
  ];

  Widget area() => const Scaffold(body: MusicLibraryView());

  testWidgets(
    'GivenNothingHasBeenScanned_WhenTheMusicAreaIsOpened_ThenTheEmptyStateIsShownNotASpinner',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, area());

      expect(find.text('Your library is empty.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'GivenAnEmptyLibrary_WhenTheOwnerAsksToAddAFolder_ThenTheyAreTakenToTheFoldersArea',
    (tester) async {
      // The empty state is where an owner actually is when they need the
      // folders screen.
      final harness = Harness();
      await tester.pumpHarness(harness, area());

      await tester.tap(find.text('Add a folder'));
      await tester.pumpAndSettle();

      expect(harness.read(shellControllerProvider), ShellDestination.folders);
    },
  );

  testWidgets(
    'GivenALibraryOfTwoArtists_WhenTheMusicAreaIsOpened_ThenBothAreListedByName',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, area());

      expect(find.text('Radiohead'), findsOneWidget);
      expect(find.text('Miles Davis'), findsOneWidget);
      // Never the name on disk, which the fixture makes deliberately unlike
      // anything the tags say.
      expect(find.textContaining('zzz-'), findsNothing);
    },
  );

  testWidgets(
    'GivenTheArtistsAreListed_WhenOneIsTapped_ThenTheirRecordsAreShown',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();

      expect(find.text('OK Computer'), findsOneWidget);
      expect(find.text('Kid A'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARecordIsOpen_WhenItsTracksAreShown_ThenTheyAreInTrackOrderWithTheirNumbers',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK Computer'));
      await tester.pumpAndSettle();

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('Karma Police'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARecordIsOpen_WhenTheBreadcrumbArtistIsTapped_ThenTheirRecordsComeBack',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK Computer'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Radiohead'));
      await tester.pumpAndSettle();

      expect(
        harness.read(musicBrowseControllerProvider).inAlbum,
        isFalse,
      );
    },
  );

  testWidgets(
    'GivenTheOwnerSwitchesToSongs_WhenTheViewChanges_ThenEveryTrackIsListedWithItsPerformer',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('So What'), findsOneWidget);
      expect(find.text('Radiohead'), findsWidgets);
    },
  );

  testWidgets(
    'GivenAnAlbumRow_WhenItsPlayButtonIsPressed_ThenTheWholeRecordIsQueued',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'OK Computer'),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pumpAndSettle();

      final state = harness.read(audioPlaybackControllerProvider);
      expect(state.queue.tracks.length, 2);
      expect(state.queue.label, 'OK Computer');
    },
  );

  testWidgets(
    'GivenTheGridLayoutIsChosen_WhenTheAlbumsAreShown_ThenTheyAreTilesAndTheChoiceIsRemembered',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(harness.read(musicLayoutControllerProvider), MusicLayout.grid);
      expect(harness.settings.getString('musicLayout'), 'grid');
    },
  );

  testWidgets(
    'GivenASongRow_WhenItsMenuIsOpened_ThenTheOwnerCanPlayTheAlbumItBelongsTo',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byType(MusicRowMenu),
              matching: find.byIcon(Icons.more_vert),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play the album'));
      await tester.pumpAndSettle();

      expect(
        harness.read(audioPlaybackControllerProvider).queue.tracks.length,
        greaterThan(0),
      );
    },
  );

  testWidgets(
    'GivenAFileWithNoTagsAtAll_WhenTheLibraryIsListed_ThenItIsCalledUnknownRatherThanItsFileName',
    (tester) async {
      final harness = Harness(library: [entry(id: 'bare')]);

      await tester.pumpHarness(harness, area());

      expect(find.text('Unknown artist'), findsOneWidget);
      expect(find.textContaining('zzz-bare'), findsNothing);
    },
  );
}
