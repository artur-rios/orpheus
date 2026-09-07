import 'package:flutter/material.dart';

import 'settings_store.dart';

/// [SettingsStore] that keeps everything for the run and nothing after it.
///
/// Two callers, and both are honest uses. It is what a test binds, so that no
/// test reads or writes the developer's own preferences. And it is what the
/// application falls back to when the platform will not give up its
/// preferences at all: an owner whose settings file is unreadable gets an
/// application that works and forgets, rather than one that will not start.
class InMemorySettingsStore implements SettingsStore {
  /// Creates a store, optionally pre-filled with [values] for the arbitrary
  /// string preferences.
  InMemorySettingsStore({
    ThemeMode themeMode = ThemeMode.system,
    Locale? locale,
    List<String> libraryFolders = const [],
    bool opensPlayerOnPlay = true,
    bool rescansAtStartup = true,
    bool fetchesLyricsOnline = true,
    double volume = 1,
    Map<String, String>? values,
  }) : _libraryFolders = [...libraryFolders],
       _values = {...?values} {
    _themeMode = themeMode;
    _locale = locale;
    _opensPlayerOnPlay = opensPlayerOnPlay;
    _rescansAtStartup = rescansAtStartup;
    _fetchesLyricsOnline = fetchesLyricsOnline;
    _volume = volume;
  }

  late ThemeMode _themeMode;
  late Locale? _locale;
  List<String> _libraryFolders;
  late bool _opensPlayerOnPlay;
  late bool _rescansAtStartup;
  late bool _fetchesLyricsOnline;
  late double _volume;
  final Map<String, String> _values;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => _themeMode = mode;

  @override
  Locale? get locale => _locale;

  @override
  Future<void> setLocale(Locale? locale) async => _locale = locale;

  @override
  List<String> get libraryFolders => List.unmodifiable(_libraryFolders);

  @override
  Future<void> setLibraryFolders(List<String> folders) async =>
      _libraryFolders = [...folders];

  @override
  bool get opensPlayerOnPlay => _opensPlayerOnPlay;

  @override
  Future<void> setOpensPlayerOnPlay(bool value) async =>
      _opensPlayerOnPlay = value;

  @override
  bool get rescansAtStartup => _rescansAtStartup;

  @override
  Future<void> setRescansAtStartup(bool value) async =>
      _rescansAtStartup = value;

  @override
  bool get fetchesLyricsOnline => _fetchesLyricsOnline;

  @override
  Future<void> setFetchesLyricsOnline(bool value) async =>
      _fetchesLyricsOnline = value;

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double value) async =>
      _volume = value.clamp(0, 1).toDouble();

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
