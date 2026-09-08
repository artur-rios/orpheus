import 'package:flutter/material.dart';

/// The owner's local preferences.
///
/// What this holds is owner-facing state changed in the interface: theme,
/// language, layout, the folders the library is built from, playback resume
/// points, volume, and the desktop window's geometry.
///
/// What it never holds is the catalog. Tracks and their tags live in the
/// catalog document the scanner writes; a settings store that starts caching
/// catalog rows becomes a second source of truth, and the two disagree the
/// first time a scan changes something.
///
/// This interface is declared here rather than in a feature so the composition
/// root can bind one implementation for the application and another for a
/// test. Tests use the in-memory implementation in `test/support/`; no test
/// reads the developer's own settings.
abstract interface class SettingsStore {
  /// The theme the owner chose, or [ThemeMode.system] when they have not.
  ThemeMode get themeMode;

  /// Records the owner's theme choice. Applied immediately, without a restart.
  Future<void> setThemeMode(ThemeMode mode);

  /// The language the owner chose, or `null` to follow the system.
  Locale? get locale;

  /// Records the owner's language choice. Applied immediately.
  Future<void> setLocale(Locale? locale);

  /// The folders the library is built from, in the order they were added.
  List<String> get libraryFolders;

  /// Records [folders] as the whole set.
  Future<void> setLibraryFolders(List<String> folders);

  /// Whether the player opens itself when a track starts, or `true` when the
  /// owner has not said.
  bool get opensPlayerOnPlay;

  /// Records [value] for the next launch.
  Future<void> setOpensPlayerOnPlay(bool value);

  /// Whether the library folders are re-scanned when the application starts,
  /// or `true` when the owner has not said.
  bool get rescansAtStartup;

  /// Records [value] for the next launch.
  Future<void> setRescansAtStartup(bool value);

  /// Whether a track with no words on this machine is looked up online, or
  /// `true` when the owner has not said.
  ///
  /// The only preference here that governs whether anything leaves the
  /// machine, which is why it is a preference at all rather than a constant.
  /// It gates the lookup and nothing else: the owner's own `.lrc` files and
  /// lyrics tags are read whatever this says.
  bool get fetchesLyricsOnline;

  /// Records [value] for the next launch.
  Future<void> setFetchesLyricsOnline(bool value);

  /// Whether the application looks for a new release when it starts, or
  /// `true` when the owner has not said.
  ///
  /// Desktop only in effect — there is nothing for it to do on Android, where
  /// a package is installed by the platform rather than by this application —
  /// but stored for every host, because a preference that means different
  /// things on different machines is a preference nobody can reason about.
  bool get checksForUpdatesOnStartup;

  /// Records [value] for the next launch.
  Future<void> setChecksForUpdatesOnStartup(bool value);

  /// A version the owner said not to ask about again, or `null` for none.
  ///
  /// What keeps "not now" from meaning "ask me every launch for ever". It
  /// holds one version rather than a list: the next release after the skipped
  /// one is a new question, and the owner has not answered it.
  String? get skippedUpdateVersion;

  /// Records [version] as unwanted, or forgets any where it is `null`.
  Future<void> setSkippedUpdateVersion(String? version);

  /// How loud playback is, 0 to 1, or 1 when the owner has not said.
  double get volume;

  /// Records [value], clamped to the range by the implementation.
  Future<void> setVolume(double value);

  /// Reads an arbitrary string preference.
  ///
  /// Features add their own typed accessors above rather than reaching for
  /// this from a screen; it exists so a feature can store its own defaults
  /// without this interface growing a method per use case.
  String? getString(String key);

  /// Writes an arbitrary string preference.
  Future<void> setString(String key, String value);

  /// Removes a preference, returning the owner to the default.
  Future<void> remove(String key);
}
