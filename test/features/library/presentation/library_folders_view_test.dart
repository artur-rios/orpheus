import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/presentation/library_folders_view.dart';

import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The folders screen: what it promises, and what it reports.
void main() {
  Widget view() => const Scaffold(body: LibraryFoldersView());

  testWidgets(
    'GivenNoFolderIsRegistered_WhenTheScreenIsShown_ThenItSaysSoAndOffersToAddOne',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, view());

      expect(find.text('No folders yet.'), findsOneWidget);
      expect(find.text('Add a folder'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheScreenIsShown_WhenTheOwnerReadsIt_ThenItPromisesNotToTouchTheirFiles',
    (tester) async {
      // The reason anyone points a program at their music collection at all.
      final harness = Harness();

      await tester.pumpHarness(harness, view());

      expect(
        find.textContaining('never moves, changes or deletes'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenAFolderIsRegistered_WhenTheScreenIsShown_ThenItIsListedByItsPath',
    (tester) async {
      final harness = Harness(
        settings: InMemorySettingsStore(
          libraryFolders: const ['/home/me/Music'],
        ),
      );

      await tester.pumpHarness(harness, view());

      expect(find.text('/home/me/Music'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAFolderIsRegistered_WhenTheOwnerRemovesIt_ThenTheyAreAskedFirst',
    (tester) async {
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, view());

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Remove this folder?'), findsOneWidget);
      expect(harness.read(libraryFoldersControllerProvider), ['/music']);
    },
  );

  testWidgets(
    'GivenTheOwnerIsAskedAboutRemovingAFolder_WhenTheyCancel_ThenItStays',
    (tester) async {
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, view());
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.read(libraryFoldersControllerProvider), ['/music']);
    },
  );

  testWidgets(
    'GivenTheOwnerConfirmsRemovingAFolder_WhenTheyAccept_ThenItLeavesTheLibrary',
    (tester) async {
      final harness = Harness(
        scanner: ScriptedScanner([
          ScanCompleted(
            catalog: MusicCatalog.empty,
            report: const ScanReport(
              tracks: 0,
              added: 0,
              removed: 1,
              reused: 0,
            ),
          ),
        ]),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, view());
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(harness.read(libraryFoldersControllerProvider), isEmpty);
    },
  );

  testWidgets(
    'GivenNoScanHasEverRun_WhenTheScreenIsShown_ThenItSaysSoRatherThanShowingAnEmptyReport',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, view());

      expect(find.text('This library has never been scanned.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheOwnerRefusedAccessPermanently_WhenAScanIsAttempted_ThenTheSettingsScreenIsOffered',
    (tester) async {
      // The only way out of a permission the system will no longer ask about.
      final harness = Harness(
        scanner: ScriptedScanner([]),
        access: FakeLibraryAccess(LibraryAccessDecision.deniedPermanently),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, view());

      await tester.tap(find.text('Scan now'));
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(harness.access.openedSettings, isTrue);
    },
  );

  testWidgets(
    'GivenAScanReportedUnreadableFiles_WhenTheScreenIsShown_ThenTheyAreNamedBehindADisclosure',
    (tester) async {
      // They are still in the library and still play, so this is a list to
      // look at rather than a problem to deal with first.
      final harness = Harness(
        scanner: ScriptedScanner([
          ScanCompleted(
            catalog: MusicCatalog.empty,
            report: const ScanReport(
              tracks: 3,
              added: 3,
              removed: 0,
              reused: 0,
              unreadable: ['/music/broken.mp3'],
            ),
          ),
        ]),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await tester.pumpHarness(harness, view());

      await tester.tap(find.text('Scan now'));
      await tester.pumpAndSettle();

      expect(
        find.text('1 file had tags that could not be read.'),
        findsOneWidget,
      );
      expect(find.text('/music/broken.mp3'), findsNothing);

      await tester.tap(find.text('1 file had tags that could not be read.'));
      await tester.pumpAndSettle();

      expect(find.text('/music/broken.mp3'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAFolderAndroidWillNotHandOver_WhenTheScanReportsIt_ThenTheWayThroughIsOffered',
    (tester) async {
      // A pen drive: mounted where an audio permission does not reach, so the
      // walk finds nothing and reports the folder as one that is not there.
      // True, and not what the owner needs to know.
      final access = FakeLibraryAccess()
        ..readsEverything = false
        ..grantsEverything = true;
      final harnessScanner = ScriptedScanner([
        ScanCompleted(
          catalog: MusicCatalog.empty,
          report: const ScanReport(
            tracks: 0,
            added: 0,
            removed: 0,
            reused: 0,
            unreachableFolders: ['/storage/1A2B-3C4D/Music'],
          ),
        ),
      ]);
      final harness = Harness(
        access: access,
        scanner: harnessScanner,
        settings: InMemorySettingsStore(
          libraryFolders: const ['/storage/1A2B-3C4D/Music'],
        ),
      );
      await harness.read(scanControllerProvider.notifier).scan();

      await tester.pumpHarness(harness, view());

      expect(find.text('Android will not hand this folder over'), findsOneWidget);

      await tester.tap(find.text('Allow all files'));
      await tester.pumpAndSettle();

      expect(access.everyFolderRequests, 1);
      // And the offer is gone, because there is nothing left to offer: the
      // scan that follows is the folders controller's own flow, exercised
      // where scans are exercised.
      expect(find.text('Allow all files'), findsNothing);
    },
  );

  testWidgets(
    'GivenEveryFolderIsAlreadyReadable_WhenAFolderIsUnreachable_ThenNoPermissionIsOffered',
    (tester) async {
      // A desktop, or an Android device that has already granted it: the
      // folder is simply not there, and a button to grant what is granted
      // would be a button that reports nothing happened.
      final harness = Harness(
        scanner: ScriptedScanner([
          ScanCompleted(
            catalog: MusicCatalog.empty,
            report: const ScanReport(
              tracks: 0,
              added: 0,
              removed: 0,
              reused: 0,
              unreachableFolders: ['/music'],
            ),
          ),
        ]),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      await harness.read(scanControllerProvider.notifier).scan();

      await tester.pumpHarness(harness, view());

      expect(find.textContaining('/music'), findsWidgets);
      expect(find.text('Allow all files'), findsNothing);
    },
  );
}
