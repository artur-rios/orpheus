import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';

/// What a backup says about itself, and the preferences it carries.
void main() {
  final createdAt = DateTime.utc(2026, 10, 19, 8, 30);

  group('backupManifest', () {
    test('GivenAnInstant_WhenBuilt_ThenItNamesTheFormatAndVersion', () {
      final manifest = backupManifest(
        createdAt: createdAt,
        orpheusVersion: '1.4.0',
        contents: const ['data.json', 'preferences.json', 'covers/p1'],
      );

      expect(manifest, {
        'format': 'orpheus-backup',
        'formatVersion': 1,
        'createdAt': '2026-10-19T08:30:00.000Z',
        'orpheusVersion': '1.4.0',
        'contents': ['data.json', 'preferences.json', 'covers/p1'],
      });
    });

    test('GivenALocalInstant_WhenBuilt_ThenItIsWrittenInUtc', () {
      final manifest = backupManifest(
        createdAt: DateTime.utc(2026, 1, 2, 3).toLocal(),
        contents: const [],
      );

      expect(manifest['createdAt'], '2026-01-02T03:00:00.000Z');
    });

    test('GivenNoVersion_WhenBuilt_ThenItIsNull', () {
      final manifest = backupManifest(createdAt: createdAt, contents: const []);

      expect(manifest.containsKey('orpheusVersion'), isTrue);
      expect(manifest['orpheusVersion'], isNull);
    });
  });

  group('PreferencesSnapshot', () {
    const snapshot = PreferencesSnapshot(
      themeMode: 'dark',
      locale: 'pt_BR',
      opensPlayerOnPlay: false,
      rescansAtStartup: false,
      fetchesLyricsOnline: false,
      checksForUpdatesOnStartup: false,
      showsAutoPlaylists: false,
      volume: 0.35,
      libraryFolders: [r'C:\Music', '/home/a/Music'],
    );

    test('GivenEveryField_WhenWrittenAsJson_ThenItHasTheDocumentedKeys', () {
      expect(snapshot.toJson(), {
        'themeMode': 'dark',
        'locale': 'pt_BR',
        'opensPlayerOnPlay': false,
        'rescansAtStartup': false,
        'fetchesLyricsOnline': false,
        'checksForUpdatesOnStartup': false,
        'showsAutoPlaylists': false,
        'volume': 0.35,
        'libraryFolders': [r'C:\Music', '/home/a/Music'],
      });
    });

    test('GivenItsJson_WhenReadBack_ThenItIsTheSameSnapshot', () {
      expect(PreferencesSnapshot.fromJson(snapshot.toJson()), snapshot);
    });

    test('GivenNoLocaleAndFullVolume_WhenRoundTripped_ThenTheyStayThat', () {
      const following = PreferencesSnapshot(
        themeMode: 'system',
        locale: null,
        opensPlayerOnPlay: true,
        rescansAtStartup: true,
        fetchesLyricsOnline: true,
        checksForUpdatesOnStartup: true,
        showsAutoPlaylists: true,
        volume: 1,
        libraryFolders: [],
      );

      final json = following.toJson();
      final back = PreferencesSnapshot.fromJson(json);

      expect(json['locale'], isNull);
      expect(back.locale, isNull);
      expect(back.volume, 1);
      expect(back, following);
    });

    test('GivenAVolumeWrittenAsAnInteger_WhenRead_ThenItIsADouble', () {
      final back = PreferencesSnapshot.fromJson({
        ...snapshot.toJson(),
        'volume': 1,
      });

      expect(back.volume, 1.0);
    });

    test('GivenMissingOrMistypedFields_WhenRead_ThenTheDefaultsStandIn', () {
      final back = PreferencesSnapshot.fromJson({
        'themeMode': 7,
        'opensPlayerOnPlay': 'yes',
        'libraryFolders': 'nope',
      });

      expect(back.themeMode, 'system');
      expect(back.locale, isNull);
      expect(back.opensPlayerOnPlay, isTrue);
      expect(back.rescansAtStartup, isTrue);
      expect(back.fetchesLyricsOnline, isTrue);
      expect(back.checksForUpdatesOnStartup, isTrue);
      expect(back.showsAutoPlaylists, isTrue);
      expect(back.volume, 1);
      expect(back.libraryFolders, isEmpty);
    });
  });
}
