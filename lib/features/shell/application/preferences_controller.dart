import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';

/// The preferences the owner can change.
class PreferencesState {
  /// Creates a state.
  const PreferencesState({
    required this.themeMode,
    required this.opensPlayerOnPlay,
    required this.rescansAtStartup,
    required this.volume,
    this.locale,
    this.unsaved = false,
  });

  /// Light, dark, or whatever the system says.
  final ThemeMode themeMode;

  /// The language, or `null` to follow the system.
  final Locale? locale;

  /// Whether the full player opens itself when a track starts.
  final bool opensPlayerOnPlay;

  /// Whether the library folders are re-scanned at every launch.
  final bool rescansAtStartup;

  /// How loud playback is, 0 to 1.
  final double volume;

  /// Whether the last change applied but could not be written.
  ///
  /// Shown rather than swallowed: a preference that will not persist is a
  /// preference the owner will set again next launch, and they are owed the
  /// reason.
  final bool unsaved;

  /// A copy with the given changes.
  PreferencesState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? opensPlayerOnPlay,
    bool? rescansAtStartup,
    double? volume,
    bool? unsaved,
  }) => PreferencesState(
    themeMode: themeMode ?? this.themeMode,
    locale: clearLocale ? null : locale ?? this.locale,
    opensPlayerOnPlay: opensPlayerOnPlay ?? this.opensPlayerOnPlay,
    rescansAtStartup: rescansAtStartup ?? this.rescansAtStartup,
    volume: volume ?? this.volume,
    unsaved: unsaved ?? this.unsaved,
  );
}

/// The preferences, applied immediately and written behind.
class PreferencesController extends Notifier<PreferencesState> {
  static final Logger _log = Logger('shell');

  @override
  PreferencesState build() {
    final settings = ref.read(settingsStoreProvider);

    return PreferencesState(
      themeMode: settings.themeMode,
      locale: settings.locale,
      opensPlayerOnPlay: settings.opensPlayerOnPlay,
      rescansAtStartup: settings.rescansAtStartup,
      volume: settings.volume,
    );
  }

  /// Applies [mode].
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, unsaved: false);
    await _write(() => ref.read(settingsStoreProvider).setThemeMode(mode));
  }

  /// Applies [locale], or `null` to follow the system.
  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(
      locale: locale,
      clearLocale: locale == null,
      unsaved: false,
    );
    await _write(() => ref.read(settingsStoreProvider).setLocale(locale));
  }

  /// Applies [value].
  Future<void> setOpensPlayerOnPlay(bool value) async {
    state = state.copyWith(opensPlayerOnPlay: value, unsaved: false);
    await _write(
      () => ref.read(settingsStoreProvider).setOpensPlayerOnPlay(value),
    );
  }

  /// Applies [value].
  Future<void> setRescansAtStartup(bool value) async {
    state = state.copyWith(rescansAtStartup: value, unsaved: false);
    await _write(
      () => ref.read(settingsStoreProvider).setRescansAtStartup(value),
    );
  }

  /// Applies [value] to the engine now, and remembers it.
  Future<void> setVolume(double value) async {
    final level = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: level, unsaved: false);
    await ref.read(audioPlaybackControllerProvider.notifier).setVolume(level);
  }

  /// Runs [write], and records a refusal rather than throwing it.
  ///
  /// The change has already applied to the state above every call to this: a
  /// preference that could not be written still holds for this session, which
  /// is the same rule the layout and the folder list follow.
  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (error) {
      _log.warning('a preference applied but could not be saved', error);
      state = state.copyWith(unsaved: true);
    }
  }
}
