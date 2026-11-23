import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';

/// The preferences kept for one run: what every test binds, and what the
/// application falls back to when the platform's preferences cannot be read.
///
/// It has to behave as the real store does, or the suite proves things about
/// a store the application never uses.
void main() {
  test(
    'GivenNothingPassed_WhenEveryPreferenceIsRead_ThenEachIsTheRealStoresDefault',
    () {
      final store = InMemorySettingsStore();

      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
      expect(store.libraryFolders, isEmpty);
      expect(store.opensPlayerOnPlay, isTrue);
      expect(store.rescansAtStartup, isTrue);
      expect(store.fetchesLyricsOnline, isTrue);
      expect(store.checksForUpdatesOnStartup, isTrue);
      expect(store.showsAutoPlaylists, isTrue);
      expect(store.skippedUpdateVersion, isNull);
      expect(store.volume, 1);
      expect(store.getString('anything'), isNull);
    },
  );

  test(
    'GivenEveryPreferenceWritten_WhenReadBack_ThenEachIsWhatWasWritten',
    () async {
      final store = InMemorySettingsStore();

      await store.setThemeMode(ThemeMode.dark);
      await store.setLocale(const Locale('pt', 'BR'));
      await store.setLibraryFolders(['/music']);
      await store.setOpensPlayerOnPlay(false);
      await store.setRescansAtStartup(false);
      await store.setFetchesLyricsOnline(false);
      await store.setChecksForUpdatesOnStartup(false);
      await store.setShowsAutoPlaylists(false);
      await store.setSkippedUpdateVersion('9.9.9');
      await store.setVolume(0.25);
      await store.setString('musicLayout', 'grid');

      expect(store.themeMode, ThemeMode.dark);
      expect(store.locale, const Locale('pt', 'BR'));
      expect(store.libraryFolders, ['/music']);
      expect(store.opensPlayerOnPlay, isFalse);
      expect(store.rescansAtStartup, isFalse);
      expect(store.fetchesLyricsOnline, isFalse);
      expect(store.checksForUpdatesOnStartup, isFalse);
      expect(store.showsAutoPlaylists, isFalse);
      expect(store.skippedUpdateVersion, '9.9.9');
      expect(store.volume, 0.25);
      expect(store.getString('musicLayout'), 'grid');
    },
  );

  for (final (name, written, read) in [
    ('AVolumeBelowSilence', -0.5, 0.0),
    ('AVolumeAboveFull', 1.5, 1.0),
  ]) {
    test(
      'Given${name}_WhenSet_ThenItIsKeptWithinSilenceAndFull',
      () async {
        final store = InMemorySettingsStore();

        await store.setVolume(written);

        expect(store.volume, read);
      },
    );
  }

  test(
    'GivenTheFoldersItWasGiven_WhenTheCallerChangesItsList_ThenTheStoreDoesNotChange',
    () async {
      final given = ['/music/a'];
      final store = InMemorySettingsStore(libraryFolders: given);

      given.add('/music/b');
      expect(store.libraryFolders, ['/music/a']);

      final written = ['/music/c'];
      await store.setLibraryFolders(written);
      written.add('/music/d');

      expect(store.libraryFolders, ['/music/c']);
    },
  );

  test(
    'GivenTheFolders_WhenTheReaderTriesToChangeThem_ThenItIsRefused',
    () {
      final store = InMemorySettingsStore(libraryFolders: ['/music/a']);

      expect(() => store.libraryFolders.add('/music/b'), throwsUnsupportedError);
    },
  );

  test(
    'GivenAValueItWasGiven_WhenRemoved_ThenItIsGoneAndTheCallersMapIsUntouched',
    () async {
      final given = {'musicLayout': 'grid'};
      final store = InMemorySettingsStore(values: given);

      await store.remove('musicLayout');

      expect(store.getString('musicLayout'), isNull);
      expect(given, {'musicLayout': 'grid'});
    },
  );

  test(
    'GivenASkippedVersion_WhenClearedWithNull_ThenNoneIsSkipped',
    () async {
      final store = InMemorySettingsStore(skippedUpdateVersion: '9.9.9');

      await store.setSkippedUpdateVersion(null);

      expect(store.skippedUpdateVersion, isNull);
    },
  );
}
