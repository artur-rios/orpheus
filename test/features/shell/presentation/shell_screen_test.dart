import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/app.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/presentation/library_folders_view.dart';
import 'package:orpheus/features/playback/presentation/genres_view.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playback/presentation/queue_view.dart';
import 'package:orpheus/features/playback/presentation/search_results_view.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlists_view.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/shell/presentation/playback_bar.dart';
import 'package:orpheus/features/shell/presentation/shell_navigation.dart';
import 'package:orpheus/features/shell/presentation/shell_screen.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The frame everything else is shown inside.
void main() {
  final library = [
    entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer'),
    entry(id: '2', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue'),
  ];

  testWidgets(
    'GivenADesktopSizedWindow_WhenTheShellIsShown_ThenTheDestinationsAreARailNotABar',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, const ShellScreen());

      expect(find.byType(ShellNavigationRail), findsOneWidget);
      expect(find.byType(ShellNavigationBar), findsNothing);
    },
  );

  testWidgets(
    'GivenAPhoneSizedWindow_WhenTheShellIsShown_ThenTheDestinationsAreABarAcrossTheBottom',
    (tester) async {
      // A rail down the side of a 411-pixel screen takes a fifth of its width,
      // and puts the entries where a thumb cannot reach them.
      final harness = Harness(library: library);

      await tester.pumpHarness(
        harness,
        const ShellScreen(),
        window: phoneWindow,
      );

      expect(find.byType(ShellNavigationBar), findsOneWidget);
      expect(find.byType(ShellNavigationRail), findsNothing);
    },
  );

  testWidgets(
    'GivenTheShellIsShown_WhenNothingIsPlaying_ThenThePlaybackBarIsStillThere',
    (tester) async {
      // Persistent means present, not present-only-while-playing: the content
      // area above it must never change height when a track starts.
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, const ShellScreen());

      expect(find.byType(PlaybackBar), findsOneWidget);
      expect(find.text('Nothing is playing'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheOwnerPicksTheFoldersDestination_WhenItIsSelected_ThenTheFoldersAreShown',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, const ShellScreen());

      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.folders);
      await tester.pumpAndSettle();

      expect(find.byType(LibraryFoldersView), findsOneWidget);
      expect(find.byType(MusicLibraryView), findsNothing);
    },
  );

  testWidgets(
    'GivenTheOwnerPicksTheQueueDestination_WhenNothingIsQueued_ThenItSaysSo',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, const ShellScreen());

      harness.read(shellControllerProvider.notifier).go(ShellDestination.queue);
      await tester.pumpAndSettle();

      expect(find.byType(QueueView), findsOneWidget);
      expect(find.text('Nothing is queued.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATermIsTyped_WhenItIsLongEnoughToMeanSomething_ThenTheResultsReplaceTheListing',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, const ShellScreen());

      await tester.enterText(find.byType(TextField), 'airbag');
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsView), findsOneWidget);
      expect(find.byType(MusicLibraryView), findsNothing);
    },
  );

  testWidgets(
    'GivenASingleCharacterIsTyped_WhenItIsTooShortToMeanAnything_ThenTheListingStays',
    (tester) async {
      // One character matches most of a library, which is a screenful of
      // results that says nothing.
      final harness = Harness(library: library);
      await tester.pumpHarness(harness, const ShellScreen());

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsView), findsNothing);
      expect(find.byType(MusicLibraryView), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATermIsActive_WhenTheOwnerOpensTheFolders_ThenTheFoldersAreNotReplacedByResults',
    (tester) async {
      // The folders area lists folders, not tracks: a term left over from the
      // music area must not replace it.
      final harness = Harness(
        library: library,
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, const ShellScreen());
      await tester.enterText(find.byType(TextField), 'airbag');
      await tester.pumpAndSettle();

      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.folders);
      await tester.pumpAndSettle();

      expect(find.byType(LibraryFoldersView), findsOneWidget);
      expect(find.byType(SearchResultsView), findsNothing);
    },
  );

  testWidgets(
    'GivenTheShell_WhenItIsDrawn_ThenGenresIsInTheRailAndInThePhoneBar',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, const ShellScreen());
      final inRail = find.descendant(
        of: find.byType(ShellNavigationRail),
        matching: find.byIcon(Icons.category_outlined),
      );
      expect(inRail, findsOneWidget);
      // Between Music and Queue: the library's second way in, beside the
      // first.
      expect(ShellDestination.values.indexOf(ShellDestination.genres), 1);

      await tester.tap(inRail);
      await tester.pumpAndSettle();
      expect(find.byType(GenresView), findsOneWidget);

      await tester.pumpHarness(
        harness,
        const ShellScreen(),
        window: phoneWindow,
      );
      expect(
        find.descendant(
          of: find.byType(ShellNavigationBar),
          matching: find.text('Genres'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenTheShell_WhenItIsDrawn_ThenThereAreFiveDestinationsWithPlaylistsAfterGenres',
    (tester) async {
      final harness = Harness(library: library);

      await tester.pumpHarness(harness, const ShellScreen());
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
        hasLength(5),
      );
      expect(ShellDestination.values, [
        ShellDestination.music,
        ShellDestination.genres,
        ShellDestination.playlists,
        ShellDestination.queue,
        ShellDestination.folders,
      ]);
      final inRail = find.descendant(
        of: find.byType(ShellNavigationRail),
        matching: find.byIcon(Icons.playlist_play_outlined),
      );

      await tester.tap(inRail);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Playlists'),
        ),
        findsOneWidget,
      );

      await tester.pumpHarness(
        harness,
        const ShellScreen(),
        window: phoneWindow,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(5),
      );
    },
  );

  testWidgets(
    'GivenAnOpenPlaylist_WhenTheSystemBackIsUsed_ThenTheListOfPlaylistsIsShown',
    (tester) async {
      final made = DateTime.utc(2026);
      final harness = Harness(
        library: library,
        playlists: [
          Playlist(
            id: 'p1',
            name: 'Road trip',
            createdAt: made,
            modifiedAt: made,
          ),
        ],
      );
      tester.view.physicalSize = desktopWindow;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const OrpheusApp(),
        ),
      );
      await tester.pumpAndSettle();
      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.playlists);
      harness.read(playlistBrowseProvider.notifier).open('p1');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(playlistBrowseProvider), isNull);
      expect(find.widgetWithText(ListTile, 'Road trip'), findsOneWidget);
      // The Music tab was never moved, and back did not try to move it.
      expect(harness.read(musicBrowseControllerProvider).inArtist, isFalse);
    },
  );

  testWidgets(
    'GivenTheOpenPlaylistWasDeleted_WhenTheShellIsShown_ThenBackHasNoLevelToClimb',
    (tester) async {
      final harness = Harness(library: library);
      tester.view.physicalSize = desktopWindow;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const OrpheusApp(),
        ),
      );
      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.playlists);
      harness.read(playlistBrowseProvider.notifier).open('gone');
      await tester.pumpAndSettle();

      final scope = tester.widget<PopScope>(
        find
            .ancestor(
              of: find.byType(ShellScreen),
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .first,
      );
      // The tab shows the list, so a back press is the platform's to use.
      expect(scope.canPop, isTrue);
    },
  );

  testWidgets(
    'GivenARecordInsideAGenre_WhenTheSystemBackIsUsed_ThenItStepsOutOneLevel',
    (tester) async {
      final harness = Harness(
        library: [
          entry(
            id: '1',
            title: 'Airbag',
            artist: 'Radiohead',
            album: 'OK Computer',
            genres: const ['Rock'],
          ),
        ],
      );
      tester.view.physicalSize = desktopWindow;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const OrpheusApp(),
        ),
      );
      await tester.pumpAndSettle();
      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.genres);
      harness.read(genreBrowseControllerProvider.notifier)
        ..openGenre('rock')
        ..openArtist('Radiohead')
        ..openAlbum('OK Computer', 'Radiohead');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final genre = harness.read(genreBrowseControllerProvider);
      expect(genre.inGenre, isTrue);
      expect(genre.music.inAlbum, isFalse);
      expect(genre.music.inArtist, isTrue);
      // The Music tab was never moved, and back did not try to move it.
      expect(harness.read(musicBrowseControllerProvider).inArtist, isFalse);
    },
  );

  /// The whole application, so that its back handler is the one under test.
  Future<Harness> app(WidgetTester tester) async {
    final harness = Harness(library: library);
    tester.view.physicalSize = desktopWindow;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const OrpheusApp(),
      ),
    );
    await tester.pumpAndSettle();

    return harness;
  }

  testWidgets(
    'GivenASelectionInsideAnAlbum_WhenBackIsPressed_ThenTheSelectionEndsAndTheAlbumStaysOpen',
    (tester) async {
      final harness = await app(tester);
      harness
          .read(musicBrowseControllerProvider.notifier)
          .openAlbum('OK Computer', 'Radiohead');
      await tester.pumpAndSettle();
      await tester.longPress(find.widgetWithText(ListTile, 'Airbag'));
      await tester.pumpAndSettle();
      expect(harness.read(songSelectionProvider).isActive, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(songSelectionProvider).isActive, isFalse);
      expect(harness.read(musicBrowseControllerProvider).inAlbum, isTrue);

      // With nothing selected, the same press goes up a level again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(musicBrowseControllerProvider).inAlbum, isFalse);
    },
  );

  testWidgets(
    'GivenASelectionInSearchResults_WhenBackIsPressed_ThenTheSelectionEndsAndTheSearchStays',
    (tester) async {
      final harness = await app(tester);
      await tester.enterText(find.byType(TextField), 'airbag');
      await tester.pumpAndSettle();
      await tester.longPress(find.widgetWithText(ListTile, 'Airbag'));
      await tester.pumpAndSettle();
      expect(harness.read(songSelectionProvider).isActive, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(songSelectionProvider).isActive, isFalse);
      expect(harness.read(searchTermProvider), 'airbag');
      expect(find.byType(SearchResultsView), findsOneWidget);

      // With nothing selected, the same press clears the search.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.read(searchTermProvider), isEmpty);
    },
  );
}
