import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';
import 'package:orpheus/features/playback/presentation/letter_bar.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playback/presentation/music_rows.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_dialog.dart';

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
    'GivenASongRow_WhenItsMenuIsOpenedByItsButton_ThenTheOwnerCanEditItsTags',
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
      await tester.tap(find.text('Edit tags…'));
      await tester.pumpAndSettle();

      expect(find.byType(EditTagsDialog), findsOneWidget);
    },
  );

  testWidgets(
    'GivenASongRow_WhenItIsRightClicked_ThenEditTagsIsOffered',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(MusicRowMenu).first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit tags…'), findsOneWidget);
    },
  );

  Finder groupMore() => find
      .descendant(
        of: find.byType(MusicGroupMenu),
        matching: find.byIcon(Icons.more_vert),
      )
      .first;

  testWidgets(
    'GivenAnAlbumRow_WhenItsMoreButtonIsPressed_ThenEditTagsAndAutofillTagsAreOffered',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      await tester.tap(groupMore());
      await tester.pumpAndSettle();

      expect(find.text('Edit tags…'), findsOneWidget);
      expect(find.text('Autofill tags…'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnArtistRow_WhenItIsRightClicked_ThenEditTagsIsOfferedAndAutofillIsNot',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());

      await tester.tap(
        find.byType(MusicGroupMenu).first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit tags…'), findsOneWidget);
      expect(find.text('Autofill tags…'), findsNothing);
    },
  );

  testWidgets(
    'GivenAnAlbumOfThreeTracks_WhenEditTagsIsPicked_ThenTheManyTrackFormOpensOverThree',
    (tester) async {
      final harness = Harness(
        library: [
          entry(id: 'a', title: 'One', artist: 'Band', album: 'Trio', track: 1),
          entry(id: 'b', title: 'Two', artist: 'Band', album: 'Trio', track: 2),
          entry(id: 'c', title: 'Three', artist: 'Band', album: 'Trio', track: 3),
        ],
      );
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      await tester.tap(groupMore());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit tags…'));
      await tester.pumpAndSettle();

      expect(find.byType(EditManyTagsDialog), findsOneWidget);
      expect(find.textContaining('3 songs'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnAlbumRow_WhenListed_ThenItHasNoSeparateAutofillButton',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, area());
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
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

  group('a long library', () {
    // Four artists under every letter but Q and X, each with one record of
    // one track: long enough that every list scrolls well past a screen.
    final letters = 'ABCDEFGHIJKLMNOPRSTUVWYZ'.split('');
    final long = [
      for (final letter in letters)
        for (var n = 0; n < 4; n++)
          entry(
            id: '$letter$n',
            title: '$letter Song $n',
            artist: '$letter Artist $n',
            album: '$letter Album $n',
            track: 1,
          ),
    ];

    /// How far the list on screen is scrolled.
    double scrolled(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .position
        .pixels;

    Future<void> scrollDown(WidgetTester tester) async {
      await tester.drag(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
    }

    Finder letter(String letter) => find.descendant(
      of: find.byType(LetterBar),
      matching: find.text(letter),
    );

    testWidgets(
      'GivenTheArtistsAreScrolled_WhenTheOwnerOpensOneAndComesBackByTheBreadcrumb_ThenTheListIsWhereTheyLeftIt',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await scrollDown(tester);
        final before = scrolled(tester);
        expect(before, greaterThan(0));

        await tester.tap(find.text('H Artist 1').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Library'));
        await tester.pumpAndSettle();

        expect(scrolled(tester), before);
      },
    );

    testWidgets(
      'GivenTheAlbumTilesAreScrolled_WhenTheOwnerOpensOneAndComesBackByTheBreadcrumb_ThenTheGridIsWhereTheyLeftIt',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await tester.tap(find.text('Albums'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.grid_view_outlined));
        await tester.pumpAndSettle();
        await scrollDown(tester);
        final before = scrolled(tester);
        expect(before, greaterThan(0));

        await tester.tap(find.byType(Card).hitTestable().first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Library'));
        await tester.pumpAndSettle();

        expect(scrolled(tester), before);
      },
    );

    testWidgets(
      'GivenTheArtistsAreScrolled_WhenTheOwnerVisitsSongsAndReturns_ThenEachViewKeptItsOwnPlace',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await scrollDown(tester);
        final artists = scrolled(tester);

        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();
        expect(scrolled(tester), 0);
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();

        expect(scrolled(tester), artists);
      },
    );

    testWidgets(
      'GivenTheArtistsAreListed_WhenALetterIsTapped_ThenTheListJumpsToTheFirstArtistUnderIt',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());

        await tester.tap(letter('M'));
        await tester.pumpAndSettle();

        expect(find.text('M Artist 0').hitTestable(), findsOneWidget);
        expect(find.text('L Artist 3').hitTestable(), findsNothing);
      },
    );

    testWidgets(
      'GivenTheAlbumTiles_WhenALetterIsTapped_ThenTheGridJumpsToTheRowOfTheFirstAlbumUnderIt',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await tester.tap(find.text('Albums'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.grid_view_outlined));
        await tester.pumpAndSettle();

        await tester.tap(letter('T'));
        await tester.pumpAndSettle();

        expect(find.text('T Album 0').hitTestable(), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTheSongs_WhenALetterIsTapped_ThenTheListJumpsToTheFirstSongUnderIt',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        await tester.tap(letter('W'));
        await tester.pumpAndSettle();

        expect(find.text('W Song 0').hitTestable(), findsOneWidget);
        expect(find.text('V Song 3').hitTestable(), findsNothing);
      },
    );

    testWidgets(
      'GivenNoArtistUnderALetter_WhenThatLetterIsTapped_ThenTheListStaysWhereItIs',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        await scrollDown(tester);
        final before = scrolled(tester);

        await tester.tap(letter('Q'));
        await tester.pumpAndSettle();

        expect(scrolled(tester), before);
      },
    );

    testWidgets(
      'GivenAnArtistIsOpen_WhenTheirRecordsAreShown_ThenThereIsNoLetterBar',
      (tester) async {
        final harness = Harness(library: long);
        await tester.pumpHarness(harness, area());
        expect(find.byType(LetterBar), findsOneWidget);

        await tester.tap(find.text('A Artist 0'));
        await tester.pumpAndSettle();

        expect(find.byType(LetterBar), findsNothing);
      },
    );
  });
}
