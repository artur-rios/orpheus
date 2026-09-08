import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/app_directories.dart';
import 'core/di/providers.dart';
import 'core/logging/app_logger.dart';
import 'core/platform/host_platform.dart';
import 'core/settings/in_memory_settings_store.dart';
import 'core/settings/settings_store.dart';
import 'core/settings/shared_preferences_settings_store.dart';
import 'features/playback/data/audio_service_media_session.dart';
import 'features/playback/domain/media_session.dart';
import 'features/shell/data/desktop_window.dart';
import 'features/updates/application/update_controller.dart';
import 'features/updates/domain/app_version.dart';

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

  final session = await _startMediaSession(platform);

  final container = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      appDirectoriesProvider.overrideWithValue(directories),
      hostPlatformProvider.overrideWithValue(platform),
      runningVersionProvider.overrideWithValue(await _runningVersion()),
      if (session != null) mediaSessionProvider.overrideWithValue(session),
    ],
  );

  // Read for its effect, which is the point of it. The session is what keeps
  // playing once the owner switches away from the application, so the thing
  // that publishes to it cannot wait to be created by a screen the system is
  // entitled to take down.
  container.read(mediaSessionControllerProvider.notifier);

  // Assigned here rather than passed to the constructor, because the window is
  // already open by this point: see [DesktopWindow.onClosing].
  window?.onClosing = () => _release(container);

  // Started after the first frame so the window is already up: the owner sees
  // the library the last scan left, and the strip above the bar says what the
  // new one is doing.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Both after the first frame, and for the same reason: the owner gets a
    // window with their library in it, and the two things that reach outside
    // the machine happen behind it.
    unawaited(
      container.read(updateControllerProvider.notifier).checkAtStartup(),
    );

    if (!container.read(preferencesControllerProvider).rescansAtStartup) return;

    unawaited(
      container.read(scanControllerProvider.notifier).scan(quick: true),
    );
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OrpheusApp(),
    ),
  );
}

/// What this build calls itself, or `null` where the platform will not say.
///
/// Read once here rather than by the update check, which runs after the first
/// frame: this is a platform channel call, and the version is also the thing
/// the check compares against, so a failure to read it is a reason not to
/// check at all rather than a reason to offer every release as an update.
Future<AppVersion?> _runningVersion() async {
  try {
    return AppVersion.tryParse((await PackageInfo.fromPlatform()).version);
  } on Object catch (error) {
    Logger('startup').warning('the running version could not be read', error);

    return null;
  }
}

/// Releases what the graph holds natively, and waits for the part that matters.
///
/// `ProviderContainer.dispose` cannot do the waiting on its own: Riverpod's
/// `onDispose` takes a synchronous callback, so a gateway whose release is a
/// future is started and never awaited. The playback engine is the one where
/// that is the difference between a clean exit and a slow one — it holds a
/// libmpv instance and, through it, the machine's audio output — so it is
/// released by hand first, and the container takes down the rest after.
///
/// `exists` rather than a plain read: the engine is built on first use, and a
/// session that never played anything should not build one in order to throw
/// it away — which on Windows means loading libmpv and opening an output
/// device as part of quitting.
Future<void> _release(ProviderContainer container) async {
  if (container.exists(audioPlayerProvider)) {
    await container.read(audioPlayerProvider).dispose();
  }

  container.dispose();
}

/// The platform's media session, or `null` to leave the silent one bound.
///
/// Android alone. The service behind it is a foreground service, and starting
/// it is what lets playback survive the application being backgrounded — which
/// is why it is started here, before the first frame, rather than at the
/// moment the owner first presses play.
///
/// A session that will not start is not fatal. Playback works without it for
/// as long as the application is on screen, which is exactly what this target
/// did before there was one, and the alternative is a music player that
/// refuses to open.
Future<MediaSession?> _startMediaSession(HostPlatform platform) async {
  if (!platform.isAndroid) return null;

  try {
    return await AudioServiceMediaSession.start();
  } on Object catch (error) {
    Logger('startup').warning(
      'the media session could not be started; playback will not continue in '
      'the background',
      error,
    );

    return null;
  }
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
