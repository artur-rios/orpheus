import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/presentation/scan_strip.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';
import 'package:orpheus/features/shell/presentation/shell_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The strip above the playback bar: what a scan is doing, and what stopped it.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Harness harnessWith({FakeLibraryAccess? access, ScriptedScanner? scanner}) =>
      Harness(
        access: access,
        scanner: scanner,
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

  testWidgets(
    'GivenNoScanIsRunningOrFailed_WhenTheShellIsShown_ThenTheStripTakesNoRoom',
    (tester) async {
      final harness = harnessWith();

      await tester.pumpHarness(harness, const Column(children: [ScanStrip()]));

      expect(tester.getSize(find.byType(ScanStrip)), Size.zero);
    },
  );

  testWidgets(
    'GivenAScanCouldNotRun_WhenTheOwnerIsAnywhereElse_ThenTheStripSaysSo',
    (tester) async {
      // The scan an owner is most likely to be failed by is the one at
      // startup, which they never asked for and are not standing in front of.
      // Before this the failure was only ever shown on the folders screen, so
      // a startup scan that could not run reported nowhere at all.
      final harness = harnessWith(
        access: FakeLibraryAccess(LibraryAccessDecision.denied),
      );
      await harness.read(scanControllerProvider.notifier).scan();

      await tester.pumpHarness(harness, const Column(children: [ScanStrip()]));

      expect(find.text(l10n.failurePermissionDenied), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheOwnerHasReadWhyTheScanFailed_WhenTheyDismissIt_ThenTheStripGoesAway',
    (tester) async {
      final harness = harnessWith(
        access: FakeLibraryAccess(LibraryAccessDecision.denied),
      );
      await harness.read(scanControllerProvider.notifier).scan();
      await tester.pumpHarness(harness, const Column(children: [ScanStrip()]));

      await tester.tap(find.text(l10n.dismiss));
      await tester.pumpAndSettle();

      expect(find.text(l10n.failurePermissionDenied), findsNothing);
      expect(tester.getSize(find.byType(ScanStrip)), Size.zero);
    },
  );

  testWidgets(
    'GivenTheOwnerIsOnTheFoldersScreen_WhenAScanFailed_ThenOnlyThatScreenSaysSo',
    (tester) async {
      // That screen says the same thing at length and carries the settings
      // button a permanent refusal needs; the same sentence twice on one
      // screen reads as two problems.
      final harness = harnessWith(
        access: FakeLibraryAccess(LibraryAccessDecision.denied),
      );
      await harness.read(scanControllerProvider.notifier).scan();
      harness
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.folders);

      await tester.pumpHarness(harness, const ShellScreen());

      expect(find.text(l10n.failurePermissionDenied), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAScanIsReadingTags_WhenTheStripIsShown_ThenItSaysHowFarItHasGot',
    (tester) async {
      // A scan that reported progress and never completed, which is the state
      // the strip exists to render. Past the walk, so the bar is a real
      // fraction — an indeterminate one animates forever and never settles.
      final harness = harnessWith(
        scanner: ScriptedScanner([
          const ScanAdvanced(
            ScanProgress(filesFound: 12, filesRead: 6, walking: false),
          ),
        ]),
      );
      await harness.read(scanControllerProvider.notifier).scan();

      await tester.pumpHarness(harness, const Column(children: [ScanStrip()]));

      expect(find.text(l10n.scanReading(6, 12)), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.5,
      );
    },
  );
}
