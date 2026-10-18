import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/shared_preferences_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The preferences as the platform keeps them.
void main() {
  Future<SharedPreferencesSettingsStore> storeWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);

    return SharedPreferencesSettingsStore.load();
  }

  test(
    'GivenNothingStored_WhenAutoPlaylistsAreRead_ThenTheyAreShown',
    () async {
      final store = await storeWith({});

      expect(store.showsAutoPlaylists, isTrue);
    },
  );

  test(
    'GivenItIsTurnedOff_WhenTheStoreIsLoadedAgain_ThenItIsStillOff',
    () async {
      final store = await storeWith({});

      await store.setShowsAutoPlaylists(false);
      final reloaded = SharedPreferencesSettingsStore(
        await SharedPreferences.getInstance(),
      );

      expect(reloaded.showsAutoPlaylists, isFalse);
    },
  );
}
