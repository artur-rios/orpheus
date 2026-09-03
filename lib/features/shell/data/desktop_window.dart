import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/settings/settings_store.dart';
import '../../../core/theme/breakpoints.dart';

/// The desktop window: its minimum size, and where it was left.
///
/// Desktop only, and constructed only where the host is one — Android has a
/// surface rather than a window, and `window_manager` has nothing to say about
/// it.
///
/// Geometry that will not load, or that is smaller than this application
/// supports, is not an error: the window opens at its default size, and the
/// owner's next move is what gets recorded.
class DesktopWindow with WindowListener {
  /// Creates the placement over [settings].
  DesktopWindow(this._settings);

  static final Logger _log = Logger('shell');

  /// The settings key the geometry is stored under.
  static const String settingsKey = 'windowBounds';

  final SettingsStore _settings;

  /// Coalesces the flurry of resize events a drag produces into one write.
  Timer? _pending;

  /// Sizes the window, restores where it was, and shows it.
  Future<void> open() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(Breakpoint.minimumWindowSize);

    final stored = _read();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: stored?.size ?? Breakpoint.defaultWindowSize,
        // Centred when there is nothing stored, and at the stored position
        // when there is — `setBounds` below is what actually places it, since
        // the options only carry a size.
        center: stored == null,
      ),
      () async {
        if (stored != null) await windowManager.setBounds(stored);
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(this);
  }

  @override
  void onWindowResized() => _scheduleWrite();

  @override
  void onWindowMoved() => _scheduleWrite();

  @override
  void onWindowClose() => unawaited(_write());

  /// Stops listening, having written where the window ended up.
  Future<void> close() async {
    _pending?.cancel();
    windowManager.removeListener(this);
    await _write();
  }

  void _scheduleWrite() {
    _pending?.cancel();
    // A drag produces a resize event per frame, and a settings write per frame
    // is a settings write per frame. Half a second after the owner stops is
    // soon enough for something read once, at the next launch.
    _pending = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_write()),
    );
  }

  Future<void> _write() async {
    try {
      final bounds = await windowManager.getBounds();
      await _settings.setString(
        settingsKey,
        jsonEncode({
          'x': bounds.left,
          'y': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        }),
      );
    } on Object catch (error) {
      _log.warning('the window geometry could not be saved', error);
    }
  }

  /// The stored geometry, or `null` where there is none worth using.
  Rect? _read() {
    final stored = _settings.getString(settingsKey);
    if (stored == null) return null;

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final width = (decoded['width'] as num).toDouble();
      final height = (decoded['height'] as num).toDouble();

      // A window smaller than the minimum is geometry written by a version
      // with a different floor, or by a window manager that ignored one. It is
      // discarded rather than clamped: half-honouring stored geometry puts the
      // window somewhere the owner never left it.
      if (width < Breakpoint.minimumWindowSize.width ||
          height < Breakpoint.minimumWindowSize.height) {
        return null;
      }

      return Rect.fromLTWH(
        (decoded['x'] as num).toDouble(),
        (decoded['y'] as num).toDouble(),
        width,
        height,
      );
    } on Object catch (error) {
      _log.warning('the window geometry could not be read', error);

      return null;
    }
  }
}
