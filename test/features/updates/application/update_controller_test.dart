import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/updates/application/update_controller.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';
import 'package:orpheus/features/updates/domain/update_installer.dart';

import '../../../support/fake_updates.dart';
import '../../../support/test_container.dart';

/// When the owner is asked, and when they are left alone.
void main() {
  test(
    'GivenANewerRelease_WhenTheApplicationStarts_ThenTheOwnerIsOfferedIt',
    () async {
      final harness = Harness(releases: ScriptedReleaseSource(release()));

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      final state = harness.read(updateControllerProvider);
      expect(state.stage, UpdateStage.available);
      expect(state.release!.version.toString(), '9.9.9');
    },
  );

  test(
    'GivenTheCheckIsSwitchedOff_WhenTheApplicationStarts_ThenNothingIsAsked',
    () async {
      final harness = Harness(
        settings: InMemorySettingsStore(checksForUpdatesOnStartup: false),
        releases: ScriptedReleaseSource(release()),
      );

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      // Not merely "no prompt": no request either. A preference that stops the
      // dialog but still asks GitHub every launch is not the preference it
      // says it is.
      expect(harness.releases.checks, 0);
      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  test(
    'GivenAStableBuild_WhenTheCheckRuns_ThenOnlyFullReleasesAreAskedFor',
    () async {
      final harness = Harness(releases: ScriptedReleaseSource(release()));

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.releases.askedForPreReleases, [false]);
    },
  );

  test(
    'GivenAStableBuild_WhenTheSourceAnswersAPreRelease_ThenItIsNotOffered',
    () async {
      // A pre-release is for somebody who chose to test one. A source that
      // answers one anyway is not a reason to move a stable owner onto it.
      final harness = Harness(
        releases: ScriptedReleaseSource(release(version: '9.9.9-beta.1')),
      );

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  test(
    'GivenABetaBuild_WhenTheCheckRuns_ThenPreReleasesAreAskedForToo',
    () async {
      final harness = Harness(
        runningVersion: AppVersion.tryParse('1.3.0-beta.1'),
        releases: ScriptedReleaseSource(release(version: '1.3.0-beta.2')),
      );

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.releases.askedForPreReleases, [true]);
      final state = harness.read(updateControllerProvider);
      expect(state.stage, UpdateStage.available);
      expect(state.release!.version.toString(), '1.3.0-beta.2');
    },
  );

  test(
    'GivenABetaBuild_WhenTheReleaseItLeadsToIsOut_ThenTheOwnerIsOfferedIt',
    () async {
      // The case D1 was about: a beta reporting itself as `1.3.0` was never
      // offered `1.3.0`. Reporting `1.3.0-beta.1`, it is.
      final harness = Harness(
        runningVersion: AppVersion.tryParse('1.3.0-beta.1'),
        releases: ScriptedReleaseSource(release(version: '1.3.0')),
      );

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      final state = harness.read(updateControllerProvider);
      expect(state.stage, UpdateStage.available);
      expect(state.release!.version.toString(), '1.3.0');
    },
  );

  test(
    'GivenABetaBuild_WhenOnlyAnEarlierBetaIsPublished_ThenNothingIsOffered',
    () async {
      final harness = Harness(
        runningVersion: AppVersion.tryParse('1.3.0-beta.2'),
        releases: ScriptedReleaseSource(release(version: '1.3.0-beta.1')),
      );

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  test(
    'GivenTheReleaseIsTheVersionAlreadyRunning_WhenTheCheckRuns_ThenNothingIsOffered',
    () async {
      final harness = Harness(releases: ScriptedReleaseSource(release(version: '1.0.0')));

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  test(
    'GivenAVersionTheOwnerSkipped_WhenTheApplicationStartsAgain_ThenItIsNotOfferedAgain',
    () async {
      final harness = Harness(releases: ScriptedReleaseSource(release()));
      final controller = harness.read(updateControllerProvider.notifier);

      await controller.checkAtStartup();
      await controller.skip();

      expect(harness.settings.skippedUpdateVersion, '9.9.9');

      await controller.checkAtStartup();
      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );

  test(
    'GivenASkippedVersion_WhenTheOwnerAsksThemselves_ThenItIsOfferedAnyway',
    () async {
      // "Not this one, automatically" is not "never mention it again". Somebody
      // who goes looking has asked.
      final harness = Harness(
        settings: InMemorySettingsStore(skippedUpdateVersion: '9.9.9'),
        releases: ScriptedReleaseSource(release()),
      );

      await harness.read(updateControllerProvider.notifier).check();

      expect(harness.read(updateControllerProvider).stage, UpdateStage.available);
    },
  );

  test(
    'GivenTheOwnerAcceptsAnUpdate_WhenTheInstallerStarts_ThenTheApplicationQuits',
    () async {
      // It has to: the running executable and the engine's libraries are the
      // files the installer is about to replace.
      final harness = Harness(releases: ScriptedReleaseSource(release()));
      final controller = harness.read(updateControllerProvider.notifier);

      await controller.checkAtStartup();
      await controller.download();

      expect(harness.updates.applied, hasLength(1));
      expect(harness.read(updateControllerProvider).stage, UpdateStage.handedOff);
      expect(harness.shutdown.quits, 1);
    },
  );

  test(
    'GivenAnInstallationNeedingRoot_WhenTheUpdateIsApplied_ThenTheCommandIsHandedBackAndNothingQuits',
    () async {
      final harness = Harness(
        releases: ScriptedReleaseSource(release()),
        updates: ScriptedUpdateInstaller(
          outcome: const UpdateNeedsCommand('sudo /tmp/x.sh --prefix /usr/local'),
        ),
      );
      final controller = harness.read(updateControllerProvider.notifier);

      await controller.checkAtStartup();
      await controller.download();

      final state = harness.read(updateControllerProvider);
      expect(state.stage, UpdateStage.needsCommand);
      expect(state.command, contains('sudo'));
      // Nothing has been replaced, so there is nothing to quit for.
      expect(harness.shutdown.quits, 0);
    },
  );

  test(
    'GivenAPackageThatFailsItsChecksum_WhenTheUpdateIsApplied_ThenItFailsAndNothingQuits',
    () async {
      final harness = Harness(
        releases: ScriptedReleaseSource(release()),
        updates: ScriptedUpdateInstaller(
          failure: UpdateFailure.checksumMismatch,
        ),
      );
      final controller = harness.read(updateControllerProvider.notifier);

      await controller.checkAtStartup();
      await controller.download();

      final state = harness.read(updateControllerProvider);
      expect(state.stage, UpdateStage.failed);
      expect(state.failure, UpdateFailure.checksumMismatch);
      expect(harness.shutdown.quits, 0);
    },
  );

  test(
    'GivenTheCheckFindsNothing_WhenTheApplicationStarts_ThenTheOwnerIsShownNothing',
    () async {
      final harness = Harness(releases: ScriptedReleaseSource());

      await harness.read(updateControllerProvider.notifier).checkAtStartup();

      expect(harness.read(updateControllerProvider).stage, UpdateStage.idle);
    },
  );
}
