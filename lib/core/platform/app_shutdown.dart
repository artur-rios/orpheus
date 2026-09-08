import 'package:window_manager/window_manager.dart';

/// How the application asks itself to close.
///
/// Behind an interface because the one thing that calls it is the update
/// hand-off — an installer is running and this process holds the files it is
/// about to replace — and a test of that flow cannot be allowed to close the
/// window the test harness is drawing into.
abstract interface class AppShutdown {
  /// Asks for the same close the window's own button asks for.
  Future<void> quit();
}

/// [AppShutdown] through the window.
///
/// `close` rather than `destroy`: it raises the same event the owner clicking
/// the button raises, so the geometry is written and the playback engine is
/// released on the way out exactly as they are on any other quit. An update is
/// not a reason to skip the tidying.
class WindowShutdown implements AppShutdown {
  /// Creates the shutdown.
  const WindowShutdown();

  @override
  Future<void> quit() => windowManager.close();
}
