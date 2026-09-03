import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/presentation/library_folders_view.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/playback/presentation/queue_view.dart';
import 'package:orpheus/features/playback/presentation/search_results_view.dart';
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
}
