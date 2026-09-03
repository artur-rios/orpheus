import 'dart:io';

/// What kind of machine the application is running on.
///
/// Behind a class rather than read from `Platform` at each call site, because
/// three of the decisions in this application turn on it — whether to manage a
/// window, whether to ask for a storage permission, and which folders a first
/// launch offers — and every one of them has to be overridable in a test that
/// runs on whatever the developer happens to have.
class HostPlatform {
  /// Creates the host as the process actually reports it.
  const HostPlatform();

  /// Whether this is Windows.
  bool get isWindows => Platform.isWindows;

  /// Whether this is Linux.
  bool get isLinux => Platform.isLinux;

  /// Whether this is Android.
  bool get isAndroid => Platform.isAndroid;

  /// Whether this host has a window to size and place.
  ///
  /// The two desktop targets. Android has a surface, not a window, and asking
  /// `window_manager` about one there throws.
  bool get isDesktop => isWindows || isLinux;

  /// Whether reading the owner's audio files needs a permission first.
  ///
  /// Android alone. On the desktops a folder the owner picked is a folder the
  /// application may read, and there is nothing to ask.
  bool get needsStoragePermission => isAndroid;

  /// The home directory, or `null` where the environment names none.
  String? get homeDirectory =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
}
