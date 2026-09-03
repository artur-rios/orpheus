import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// [SettingsStore] over `shared_preferences`.
///
/// Loaded once, into memory, and written through: every getter here is read
/// during a build, and a preference read that awaited the disk would be a
/// frame that waited on it.
class SharedPreferencesSettingsStore implements SettingsStore {
  /// Wraps an already-loaded [preferences].
  SharedPreferencesSettingsStore(this._preferences);

  /// Loads the store the platform holds.
  static Future<SharedPreferencesSettingsStore> load() async =>
      SharedPreferencesSettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  /// The key the theme choice is stored under.
  static const String themeModeKey = 'themeMode';

  /// The key the language choice is stored under.
  static const String localeKey = 'locale';

  /// The key the library folders are stored under.
  static const String libraryFoldersKey = 'libraryFolders';

  /// The key the auto-open preference is stored under.
  static const String opensPlayerOnPlayKey = 'opensPlayerOnPlay';

  /// The key the startup-rescan preference is stored under.
  static const String rescansAtStartupKey = 'rescansAtStartup';

  /// The key the volume is stored under.
  static const String volumeKey = 'volume';

  @override
  ThemeMode get themeMode => switch (_preferences.getString(themeModeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    // Anything else — absent, or a value written by a version that offered
    // more of them — is the owner having expressed no preference.
    _ => ThemeMode.system,
  };

  @override
  Future<void> setThemeMode(ThemeMode mode) =>
      _preferences.setString(themeModeKey, mode.name);

  @override
  Locale? get locale {
    final stored = _preferences.getString(localeKey);
    if (stored == null || stored.isEmpty) return null;

    final parts = stored.split('_');

    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  @override
  Future<void> setLocale(Locale? locale) {
    if (locale == null) return _preferences.remove(localeKey);

    final country = locale.countryCode;

    return _preferences.setString(
      localeKey,
      country == null || country.isEmpty
          ? locale.languageCode
          : '${locale.languageCode}_$country',
    );
  }

  @override
  List<String> get libraryFolders =>
      _preferences.getStringList(libraryFoldersKey) ?? const [];

  @override
  Future<void> setLibraryFolders(List<String> folders) =>
      _preferences.setStringList(libraryFoldersKey, folders);

  @override
  bool get opensPlayerOnPlay =>
      _preferences.getBool(opensPlayerOnPlayKey) ?? true;

  @override
  Future<void> setOpensPlayerOnPlay(bool value) =>
      _preferences.setBool(opensPlayerOnPlayKey, value);

  @override
  bool get rescansAtStartup => _preferences.getBool(rescansAtStartupKey) ?? true;

  @override
  Future<void> setRescansAtStartup(bool value) =>
      _preferences.setBool(rescansAtStartupKey, value);

  @override
  double get volume => _preferences.getDouble(volumeKey) ?? 1;

  @override
  Future<void> setVolume(double value) =>
      _preferences.setDouble(volumeKey, value.clamp(0, 1).toDouble());

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
