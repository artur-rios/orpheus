import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/playback/application/music_layout_controller.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';

import '../../../support/test_container.dart';

/// How the music area draws its artists and albums, remembered.
void main() {
  const key = MusicLayoutController.settingsKey;

  test('GivenNoStoredChoice_WhenTheLayoutIsRead_ThenItIsTheList', () {
    final harness = Harness();

    expect(harness.read(musicLayoutControllerProvider), MusicLayout.list);
  });

  test('GivenAStoredGrid_WhenTheLayoutIsRead_ThenItIsTheGrid', () {
    final harness = Harness(
      settings: InMemorySettingsStore(values: {key: 'grid'}),
    );

    expect(harness.read(musicLayoutControllerProvider), MusicLayout.grid);
  });

  test(
    'GivenAStoredValueThisVersionDoesNotKnow_WhenTheLayoutIsRead_ThenItIsTheList',
    () {
      final harness = Harness(
        settings: InMemorySettingsStore(values: {key: 'carousel'}),
      );

      expect(harness.read(musicLayoutControllerProvider), MusicLayout.list);
    },
  );

  test(
    'GivenTheGridChosen_WhenTheNextLaunchReadsTheSettings_ThenItIsTheGrid',
    () async {
      final settings = InMemorySettingsStore();
      final harness = Harness(settings: settings);

      await harness.container
          .read(musicLayoutControllerProvider.notifier)
          .choose(MusicLayout.grid);

      expect(settings.getString(key), 'grid');
      expect(
        Harness(settings: settings).read(musicLayoutControllerProvider),
        MusicLayout.grid,
      );
    },
  );

  test(
    'GivenSettingsThatCannotBeWritten_WhenTheGridIsChosen_ThenItStillApplies',
    () async {
      final harness = Harness(settings: _UnwritableSettings());

      await harness.container
          .read(musicLayoutControllerProvider.notifier)
          .choose(MusicLayout.grid);

      expect(harness.read(musicLayoutControllerProvider), MusicLayout.grid);
    },
  );
}

/// Preferences that refuse every arbitrary write.
class _UnwritableSettings extends InMemorySettingsStore {
  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('read-only');
}
