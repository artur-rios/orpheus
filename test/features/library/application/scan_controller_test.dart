import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/failures/failure.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Running a scan, and what the owner is told about it.
void main() {
  final scanned = MusicCatalog(
    entries: albumArtistsAcross([
      entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK'),
    ]),
    scannedAt: DateTime.utc(2026, 6),
  );

  const report = ScanReport(tracks: 1, added: 1, removed: 0, reused: 0);

  Harness harnessWith(ScriptedScanner scanner, {FakeLibraryAccess? access}) =>
      Harness(
        scanner: scanner,
        access: access,
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

  test(
    'GivenAFolderIsRegistered_WhenAScanFinishes_ThenTheLibraryOnScreenIsWhatItFound',
    () async {
      final harness = harnessWith(
        ScriptedScanner([
          const ScanAdvanced(ScanProgress(filesFound: 1)),
          ScanCompleted(catalog: scanned, report: report),
        ]),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      final library = await harness.library();
      expect(library.entries.single.title, 'Airbag');
    },
  );

  test(
    'GivenAScanFinishes_WhenItsCatalogIsHandedOver_ThenItIsWrittenForTheNextLaunch',
    () async {
      final harness = harnessWith(
        ScriptedScanner([ScanCompleted(catalog: scanned, report: report)]),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      expect(harness.catalogs.written.single.entries.single.title, 'Airbag');
    },
  );

  test(
    'GivenAScanFinishes_WhenTheOwnerLooksAtTheFoldersScreen_ThenTheReportIsStillThere',
    () async {
      // A report that vanished with the progress bar would be a report nobody
      // saw.
      final harness = harnessWith(
        ScriptedScanner([ScanCompleted(catalog: scanned, report: report)]),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      final state = harness.read(scanControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.report?.tracks, 1);
    },
  );

  test(
    'GivenNoFolderIsRegistered_WhenAScanIsAskedFor_ThenNothingIsScannedAndNothingIsAsked',
    () async {
      // A fresh install must not open on a permission dialog for files it has
      // not been pointed at.
      final scanner = ScriptedScanner([]);
      final access = FakeLibraryAccess();
      final harness = Harness(scanner: scanner, access: access);

      await harness.read(scanControllerProvider.notifier).scan();

      expect(scanner.requests, isEmpty);
      expect(access.requests, 0);
    },
  );

  test(
    'GivenTheOwnerRefusesAccessToTheirFiles_WhenAScanIsAskedFor_ThenNothingIsScannedAndTheyAreTold',
    () async {
      final scanner = ScriptedScanner([]);
      final harness = harnessWith(
        scanner,
        access: FakeLibraryAccess(LibraryAccessDecision.denied),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      expect(scanner.requests, isEmpty);
      expect(
        harness.read(scanControllerProvider).failure,
        isA<StoragePermissionDenied>().having(
          (failure) => failure.permanently,
          'permanently',
          isFalse,
        ),
      );
    },
  );

  test(
    'GivenTheOwnerRefusedAccessPermanently_WhenAScanIsAskedFor_ThenTheFailureSaysSo',
    () async {
      // The difference between offering a retry and offering the settings
      // screen.
      final harness = harnessWith(
        ScriptedScanner([]),
        access: FakeLibraryAccess(LibraryAccessDecision.deniedPermanently),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      expect(
        harness.read(scanControllerProvider).failure,
        isA<StoragePermissionDenied>().having(
          (failure) => failure.permanently,
          'permanently',
          isTrue,
        ),
      );
    },
  );

  test(
    'GivenTheScanItselfFails_WhenItReportsSo_ThenTheProgressGivesWayToTheFailure',
    () async {
      final harness = harnessWith(
        ScriptedScanner([
          const ScanAdvanced(ScanProgress(filesFound: 3)),
          const ScanFailed(UnexpectedFailure()),
        ]),
      );

      await harness.read(scanControllerProvider.notifier).scan();

      final state = harness.read(scanControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.progress, isNull);
      expect(state.failure, isA<UnexpectedFailure>());
    },
  );

  test(
    'GivenTheOwnerHasReadTheReport_WhenTheyAcknowledgeIt_ThenTheStripHasNothingToSay',
    () async {
      final harness = harnessWith(
        ScriptedScanner([ScanCompleted(catalog: scanned, report: report)]),
      );
      await harness.read(scanControllerProvider.notifier).scan();

      harness.read(scanControllerProvider.notifier).acknowledge();

      expect(harness.read(scanControllerProvider).report, isNull);
      expect(harness.read(scanControllerProvider).isVisible, isFalse);
    },
  );

  test(
    'GivenAPreviousCatalog_WhenAScanIsAskedFor_ThenItIsHandedToTheScannerToReuse',
    () async {
      // What makes a re-scan of an unchanged library cheap enough to run at
      // every launch.
      final scanner = ScriptedScanner([
        ScanCompleted(catalog: scanned, report: report),
      ]);
      final harness = harnessWith(scanner);

      await harness.read(scanControllerProvider.notifier).scan();

      expect(scanner.requests.single, ['/music']);
    },
  );

  group('what a scan that changed nothing costs', () {
    const nothingChanged = ScanReport(
      tracks: 1,
      added: 0,
      removed: 0,
      reused: 1,
    );

    test(
      'GivenAScanThatAddedAndRemovedNothing_WhenItFinishes_ThenTheCatalogIsNotRewritten',
      () async {
        // The entries it carried over came out of the stored document in the
        // first place, so writing them back would encode the file that is
        // already on disk — the most expensive thing a launch does, for
        // nothing.
        final harness = harnessWith(
          ScriptedScanner([
            ScanCompleted(catalog: scanned, report: nothingChanged),
          ]),
        );

        await harness.read(scanControllerProvider.notifier).scan();

        expect(harness.catalogs.written, isEmpty);
      },
    );

    test(
      'GivenAScanThatChangedNothing_WhenItFinishes_ThenTheLibraryOnScreenIsStillTheOneItFound',
      () async {
        // Not written, but still handed over: the catalog carries the time of
        // the scan, and the folder screen shows it.
        final harness = harnessWith(
          ScriptedScanner([
            ScanCompleted(catalog: scanned, report: nothingChanged),
          ]),
        );

        await harness.read(scanControllerProvider.notifier).scan();

        expect((await harness.library()).scannedAt, scanned.scannedAt);
      },
    );

    test(
      'GivenAScanThatRemovedATrack_WhenItFinishes_ThenTheCatalogIsWritten',
      () async {
        final harness = harnessWith(
          ScriptedScanner([
            ScanCompleted(
              catalog: scanned,
              report: const ScanReport(
                tracks: 1,
                added: 0,
                removed: 1,
                reused: 1,
              ),
            ),
          ]),
        );

        await harness.read(scanControllerProvider.notifier).scan();

        expect(harness.catalogs.written, hasLength(1));
      },
    );
  });

  group('which walk a scan asks for', () {
    Harness seeded(ScriptedScanner scanner) => Harness(
      library: [entry(id: '1', title: 'Airbag', artist: 'Radiohead')],
      scanner: scanner,
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );

    test(
      'GivenTheScanThatRunsAtStartup_WhenItIsAskedFor_ThenItAsksForTheCheapWalk',
      () async {
        final scanner = ScriptedScanner([
          ScanCompleted(catalog: scanned, report: report),
        ]);
        final harness = seeded(scanner);

        await harness
            .read(scanControllerProvider.notifier)
            .scan(quick: true);

        // The moment the stored catalog was written, which is what a folder's
        // timestamp is measured against.
        expect(scanner.unchangedSinces.single, DateTime.utc(2026));
      },
    );

    test(
      'GivenTheScanTheOwnerAsksForByHand_WhenItRuns_ThenEveryFileIsStated',
      () async {
        // The button they press when they have just re-tagged something, which
        // is the case the cheap walk cannot see.
        final scanner = ScriptedScanner([
          ScanCompleted(catalog: scanned, report: report),
        ]);
        final harness = seeded(scanner);

        await harness.read(scanControllerProvider.notifier).scan();

        expect(scanner.unchangedSinces.single, isNull);
      },
    );
  });
}
