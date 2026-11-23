import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:orpheus/core/settings/shared_preferences_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The preferences as the platform keeps them.
///
/// Every preference has to come back from a fresh load as it was written, and
/// one that was never written, or was written by some other version in a form
/// this one does not know, has to read as the default rather than break the
/// start of the application.
void main() {
  Future<SharedPreferencesSettingsStore> storeWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);

    return SharedPreferencesSettingsStore.load();
  }

  /// The same preferences, read back from the platform as the next launch
  /// would read them.
  Future<SharedPreferencesSettingsStore> reloaded() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();

    return SharedPreferencesSettingsStore(preferences);
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

      expect((await reloaded()).showsAutoPlaylists, isFalse);
    },
  );

  test(
    'GivenNothingStored_WhenEveryPreferenceIsRead_ThenEachIsItsDefault',
    () async {
      final store = await storeWith({});

      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
      expect(store.libraryFolders, isEmpty);
      expect(store.opensPlayerOnPlay, isTrue);
      expect(store.rescansAtStartup, isTrue);
      expect(store.fetchesLyricsOnline, isTrue);
      expect(store.checksForUpdatesOnStartup, isTrue);
      expect(store.skippedUpdateVersion, isNull);
      expect(store.volume, 1);
      expect(store.getString('anything'), isNull);
    },
  );

  for (final mode in ThemeMode.values) {
    test(
      'GivenTheThemeSetTo${mode.name}_WhenLoadedAgain_ThenItIs${mode.name}',
      () async {
        final store = await storeWith({});

        await store.setThemeMode(mode);

        expect((await reloaded()).themeMode, mode);
      },
    );
  }

  for (final (name, stored) in [
    ('AnEmptyTheme', ''),
    ('AThemeThisVersionDoesNotOffer', 'sepia'),
    ('AThemeInTheWrongCase', 'Dark'),
  ]) {
    test(
      'Given${name}Stored_WhenRead_ThenItIsTheSystemTheme',
      () async {
        final store = await storeWith({
          SharedPreferencesSettingsStore.themeModeKey: stored,
        });

        expect(store.themeMode, ThemeMode.system);
      },
    );
  }

  test(
    'GivenALanguageWithNoCountry_WhenLoadedAgain_ThenItIsTheLanguageAlone',
    () async {
      final store = await storeWith({});

      await store.setLocale(const Locale('pt'));

      expect(
        (await SharedPreferences.getInstance()).getString(
          SharedPreferencesSettingsStore.localeKey,
        ),
        'pt',
      );
      final locale = (await reloaded()).locale!;
      expect(locale.languageCode, 'pt');
      expect(locale.countryCode, isNull);
    },
  );

  test(
    'GivenALanguageWithACountry_WhenLoadedAgain_ThenBothComeBack',
    () async {
      final store = await storeWith({});

      await store.setLocale(const Locale('pt', 'BR'));

      expect(
        (await SharedPreferences.getInstance()).getString(
          SharedPreferencesSettingsStore.localeKey,
        ),
        'pt_BR',
      );
      expect((await reloaded()).locale, const Locale('pt', 'BR'));
    },
  );

  test(
    'GivenALanguageWithAnEmptyCountry_WhenStored_ThenOnlyTheLanguageIsWritten',
    () async {
      final store = await storeWith({});

      await store.setLocale(const Locale('en', ''));

      expect(
        (await SharedPreferences.getInstance()).getString(
          SharedPreferencesSettingsStore.localeKey,
        ),
        'en',
      );
    },
  );

  test(
    'GivenAChosenLanguage_WhenSetBackToTheSystemOne_ThenNoneIsStored',
    () async {
      final store = await storeWith({
        SharedPreferencesSettingsStore.localeKey: 'pt_BR',
      });

      await store.setLocale(null);

      expect(
        (await SharedPreferences.getInstance()).containsKey(
          SharedPreferencesSettingsStore.localeKey,
        ),
        isFalse,
      );
      expect((await reloaded()).locale, isNull);
    },
  );

  test(
    'GivenAnEmptyStoredLanguage_WhenRead_ThenThereIsNoChoice',
    () async {
      final store = await storeWith({
        SharedPreferencesSettingsStore.localeKey: '',
      });

      expect(store.locale, isNull);
    },
  );

  test(
    'GivenLibraryFolders_WhenLoadedAgain_ThenTheyComeBackInOrder',
    () async {
      final store = await storeWith({});

      await store.setLibraryFolders(['/music/b', '/music/a']);

      expect((await reloaded()).libraryFolders, ['/music/b', '/music/a']);
    },
  );

  for (final (name, write, read) in <(
    String,
    Future<void> Function(SharedPreferencesSettingsStore, bool),
    bool Function(SharedPreferencesSettingsStore),
  )>[
    (
      'OpensPlayerOnPlay',
      (store, value) => store.setOpensPlayerOnPlay(value),
      (store) => store.opensPlayerOnPlay,
    ),
    (
      'RescansAtStartup',
      (store, value) => store.setRescansAtStartup(value),
      (store) => store.rescansAtStartup,
    ),
    (
      'FetchesLyricsOnline',
      (store, value) => store.setFetchesLyricsOnline(value),
      (store) => store.fetchesLyricsOnline,
    ),
    (
      'ChecksForUpdatesOnStartup',
      (store, value) => store.setChecksForUpdatesOnStartup(value),
      (store) => store.checksForUpdatesOnStartup,
    ),
  ]) {
    test(
      'Given${name}TurnedOff_WhenLoadedAgain_ThenItIsStillOffAndTurnsBackOn',
      () async {
        final store = await storeWith({});

        await write(store, false);
        expect(read(await reloaded()), isFalse);

        await write(store, true);
        expect(read(await reloaded()), isTrue);
      },
    );
  }

  test(
    'GivenASkippedVersion_WhenLoadedAgainAndThenCleared_ThenItIsForgotten',
    () async {
      final store = await storeWith({});

      await store.setSkippedUpdateVersion('9.9.9');
      expect((await reloaded()).skippedUpdateVersion, '9.9.9');

      await store.setSkippedUpdateVersion(null);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          SharedPreferencesSettingsStore.skippedUpdateVersionKey,
        ),
        isFalse,
      );
      expect((await reloaded()).skippedUpdateVersion, isNull);
    },
  );

  for (final (name, written, read) in [
    ('APartVolume', 0.4, 0.4),
    ('Silence', 0.0, 0.0),
    ('FullVolume', 1.0, 1.0),
    ('AVolumeBelowSilence', -0.5, 0.0),
    ('AVolumeAboveFull', 1.5, 1.0),
  ]) {
    test(
      'Given${name}Set_WhenLoadedAgain_ThenItIsKeptWithinSilenceAndFull',
      () async {
        final store = await storeWith({});

        await store.setVolume(written);

        expect((await reloaded()).volume, read);
      },
    );
  }

  test(
    'GivenAnArbitraryValue_WhenWrittenAndRemoved_ThenItIsReadAndThenGone',
    () async {
      final store = await storeWith({});

      await store.setString('musicLayout', 'grid');
      expect((await reloaded()).getString('musicLayout'), 'grid');

      await store.remove('musicLayout');
      expect((await reloaded()).getString('musicLayout'), isNull);
    },
  );
}
