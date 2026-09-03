import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/app_directories.dart';
import 'core/di/providers.dart';
import 'core/logging/app_logger.dart';
import 'core/platform/host_platform.dart';
import 'core/settings/in_memory_settings_store.dart';
import 'core/settings/settings_store.dart';
import 'core/settings/shared_preferences_settings_store.dart';
import 'features/shell/data/desktop_window.dart';

/// The entry point.
///
/// It does the least it can: start logging, resolve the two things the
/// provider graph cannot build for itself — the settings store and the
/// directories this application writes to — put a window on screen, and hand
/// over to the shell.
///
/// The scan is not part of it. A library scan opens and parses every audio
/// file the owner has, and a launch that waited for one would be as slow as
/// the first launch every time; it is started after the first frame and
/// reports from the strip above the playback bar.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.initialize();

  const platform = HostPlatform();
  final settings = await _loadSettings();
  final directories = AppDirectories(
    (await getApplicationSupportDirectory()).path,
  );

  DesktopWindow? window;
  if (platform.isDesktop) {
    window = DesktopWindow(settings);
    await window.open();
  }

  final container = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      appDirectoriesProvider.overrideWithValue(directories),
      hostPlatformProvider.overrideWithValue(platform),
    ],
  );

  // Started after the first frame so the window is already up: the owner sees
  // the library the last scan left, and the strip above the bar says what the
  // new one is doing.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!container.read(preferencesControllerProvider).rescansAtStartup) return;

    unawaited(container.read(scanControllerProvider.notifier).scan());
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OrpheusApp(),
    ),
  );
}

/// The settings store, or an empty one where the platform will not give it up.
///
/// Preferences that cannot be read are not fatal and never have been: the
/// application opens at its defaults, and the owner's next choice is what gets
/// recorded.
Future<SettingsStore> _loadSettings() async {
  try {
    return await SharedPreferencesSettingsStore.load();
  } on Object catch (error) {
    Logger('startup').warning(
      'preferences could not be read; starting at the defaults',
      error,
    );

    return InMemorySettingsStore();
  }
}
