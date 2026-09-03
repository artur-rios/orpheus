import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/host_platform.dart';
import '../domain/library_access.dart';

/// [LibraryAccess] over `permission_handler`.
///
/// Asks on Android and nowhere else. On Windows and Linux a folder the owner
/// pointed at is a folder the application may read, and a permission dialog
/// there would be a question with no system behind it.
class PermissionLibraryAccess implements LibraryAccess {
  /// Creates the gate for [platform].
  const PermissionLibraryAccess({this.platform = const HostPlatform()});

  static final Logger _log = Logger('library');

  /// Which host is running, which is what decides whether anything is asked.
  final HostPlatform platform;

  @override
  Future<LibraryAccessDecision> request() async {
    if (!platform.needsStoragePermission) return LibraryAccessDecision.granted;

    // Android 13 replaced the single storage permission with per-media ones,
    // and READ_MEDIA_AUDIO is the one this application wants: it asks for
    // exactly what a music player reads and nothing else. On an older release
    // that permission does not exist and the request answers permanently
    // denied, which is why the legacy one is tried behind it rather than
    // instead of it.
    final audio = await Permission.audio.request();
    if (audio.isGranted || audio.isLimited) {
      return LibraryAccessDecision.granted;
    }

    final storage = await Permission.storage.request();
    if (storage.isGranted) return LibraryAccessDecision.granted;

    // Permanently only when both agree it is: on Android 13+ the legacy
    // permission always answers permanently denied, and letting that decide
    // would send an owner who simply pressed "deny" once to the settings
    // screen.
    if (audio.isPermanentlyDenied && storage.isPermanentlyDenied) {
      _log.info('audio access was refused permanently');
      return LibraryAccessDecision.deniedPermanently;
    }

    return LibraryAccessDecision.denied;
  }

  @override
  Future<void> openSettings() async {
    if (!platform.needsStoragePermission) return;

    await openAppSettings();
  }
}
