import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';

import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// The preferences: applied at once, written behind, and honest when the write
/// did not land.
void main() {
  test(
    'GivenAPreferenceCannotBeSaved_WhenItIsChanged_ThenItAppliesAndSaysItWasNotSaved',
    () async {
      final harness = Harness(settings: UnwritableSettingsStore());
      final preferences = harness.read(preferencesControllerProvider.notifier);

      await preferences.setThemeMode(ThemeMode.dark);

      final state = harness.read(preferencesControllerProvider);
      expect(state.themeMode, ThemeMode.dark);
      expect(state.unsaved, isTrue);
    },
  );

  test(
    'GivenTheVolumeCannotBeSaved_WhenItIsChanged_ThenItFollowsTheSameRule',
    () async {
      // The one control that did not. It reached the player directly rather
      // than through the same guarded write as its neighbours, so a refused
      // write escaped as an unhandled error out of a slider's callback and
      // the owner was never told.
      final harness = Harness(settings: UnwritableSettingsStore());
      final preferences = harness.read(preferencesControllerProvider.notifier);

      await preferences.setVolume(0.4);

      final state = harness.read(preferencesControllerProvider);
      expect(state.volume, 0.4);
      expect(state.unsaved, isTrue);
      // And it still reached the engine, which is what the owner can hear.
      expect(harness.player.volumes, contains(0.4));
    },
  );

  test(
    'GivenAPreferenceIsSavedNormally_WhenItIsChanged_ThenNothingIsReported',
    () async {
      final harness = Harness();
      final preferences = harness.read(preferencesControllerProvider.notifier);

      await preferences.setVolume(0.4);

      expect(harness.read(preferencesControllerProvider).unsaved, isFalse);
      expect(harness.settings.volume, 0.4);
    },
  );
}
