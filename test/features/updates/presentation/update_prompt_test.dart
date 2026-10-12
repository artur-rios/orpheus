import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/shell/presentation/preferences_dialog.dart';
import 'package:orpheus/features/updates/application/update_controller.dart';
import 'package:orpheus/features/updates/domain/app_release.dart';
import 'package:orpheus/features/updates/domain/update_installer.dart';
import 'package:orpheus/features/updates/presentation/update_prompt.dart';

import '../../../support/fake_updates.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// What the owner is actually shown.
void main() {
  testWidgets(
    'GivenANewerRelease_WhenTheCheckRuns_ThenTheOwnerIsAskedAndCanRefuse',
    (tester) async {
      final harness = Harness(releases: ScriptedReleaseSource(release()));

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();

      expect(find.text('Orpheus 9.9.9 is available'), findsOneWidget);
      expect(find.text('You have 1.0.0.'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Refused rather than applied: nothing was downloaded and nothing quit.
      expect(find.text('Orpheus 9.9.9 is available'), findsNothing);
      // And gone, not emptied: a dialog route left behind keeps its barrier
      // over the application and swallows the next click.
      expect(
        Navigator.of(tester.element(find.byType(Scaffold))).canPop(),
        isFalse,
      );
      expect(harness.updates.applied, isEmpty);
      expect(harness.shutdown.quits, 0);
    },
  );

  testWidgets(
    'GivenAnOfferedRelease_WhenTheOwnerSkipsIt_ThenTheDialogIsGone',
    (tester) async {
      final harness = Harness(releases: ScriptedReleaseSource(release()));

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();

      expect(
        Navigator.of(tester.element(find.byType(Scaffold))).canPop(),
        isFalse,
      );
      expect(harness.settings.skippedUpdateVersion, '9.9.9');
    },
  );

  testWidgets(
    'GivenAnOfferedRelease_WhenTheOwnerTapsOutsideTheDialog_ThenTheOfferIsSetAside',
    (tester) async {
      // The barrier closes the route without a button being pressed. The
      // controller is told, so it is not left offering a release nobody can
      // see — and a later offer is free to open a dialog again.
      final harness = Harness(releases: ScriptedReleaseSource(release()));

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  testWidgets(
    'GivenADownloadOfUnknownSize_WhenItIsRunning_ThenItSaysItIsDownloading',
    (tester) async {
      // A server that does not say how big the file is reports no fraction
      // for the whole download. That is still a download, not the checksum.
      final installer = _HeldInstaller();
      final harness = Harness(
        releases: ScriptedReleaseSource(release()),
        updates: installer,
      );

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update now'));
      await tester.pump();

      installer.report(null);
      await tester.pump();
      expect(find.text('Downloading…'), findsOneWidget);

      installer.report(1);
      await tester.pump();
      expect(find.text('Checking what was downloaded…'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNoNewerRelease_WhenTheCheckRuns_ThenNothingInterruptsTheOwner',
    (tester) async {
      final harness = Harness(releases: ScriptedReleaseSource());

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'GivenADownloadThatFailsItsChecksum_WhenItIsReported_ThenThereIsNoWayToRetryIt',
    (tester) async {
      // Everything else here offers "Try again". This one must not: what
      // failed is not the network, and a retry button invites the owner to
      // keep pressing until something they should not run finally does.
      final harness = Harness(
        releases: ScriptedReleaseSource(release()),
        updates: ScriptedUpdateInstaller(
          failure: UpdateFailure.checksumMismatch,
        ),
      );

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      final controller = harness.read(updateControllerProvider.notifier);
      await controller.checkAtStartup();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not what the release published'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenADownloadThatFailed_WhenItIsReported_ThenItCanBeTriedAgain',
    (tester) async {
      final harness = Harness(
        releases: ScriptedReleaseSource(release()),
        updates: ScriptedUpdateInstaller(
          failure: UpdateFailure.downloadFailed,
        ),
      );

      await tester.pumpHarness(
        harness,
        const UpdatePromptScope(child: Scaffold()),
      );
      await harness.read(updateControllerProvider.notifier).checkAtStartup();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenADesktopHost_WhenThePreferencesAreOpened_ThenTheStartupCheckCanBeTurnedOff',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, const _OpenPreferences());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final switchFinder = find.ancestor(
        of: find.text('Check for updates when Orpheus starts'),
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: switchFinder, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(harness.settings.checksForUpdatesOnStartup, isFalse);
    },
  );

  testWidgets(
    'GivenTheCheckIsTurnedBackOn_WhenItWasOffWithAVersionSkipped_ThenTheSkipIsForgotten',
    (tester) async {
      // Somebody switching it back on is asking to hear about what is out
      // there, including the release they once waved away.
      final harness = Harness(
        settings: InMemorySettingsStore(skippedUpdateVersion: '9.9.9'),
      );

      await tester.pumpHarness(harness, const _OpenPreferences());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final switchFinder = find.ancestor(
        of: find.text('Check for updates when Orpheus starts'),
        matching: find.byType(SwitchListTile),
      );
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: switchFinder, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(harness.settings.skippedUpdateVersion, isNull);
    },
  );
}

/// A button that opens the preferences, so the dialog has a navigator.
class _OpenPreferences extends StatelessWidget {
  const _OpenPreferences();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => PreferencesDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}

/// An installer whose download stays open until the test is done with it,
/// reporting whatever the test tells it to.
class _HeldInstaller extends ScriptedUpdateInstaller {
  void Function(double? progress)? _onProgress;

  /// Reports [fraction] to whoever is watching the download.
  void report(double? fraction) => _onProgress?.call(fraction);

  @override
  Future<UpdateOutcome> apply(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  }) {
    _onProgress = onProgress;

    return Completer<UpdateOutcome>().future;
  }
}
