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
/// It opens maximized unless the owner last left it un-maximized, in which
/// case it opens where they left it. What is recorded is always the window's
/// *normal* geometry — the rectangle it returns to when un-maximized — beside
/// whether it was maximized: a maximized window's own rectangle is the screen,
/// and storing that would leave nothing for the restore button to go back to.
///
/// Geometry that will not load, or that is smaller than this application
/// supports, is not an error: the window opens at its default size, and the
/// owner's next move is what gets recorded.
class DesktopWindow with WindowListener {
  /// Creates the placement over [settings].
  ///
  /// [shutdownBudget] is a seam for the test that asserts the window closes
  /// even when the release behind it never finishes; nothing else passes one.
  DesktopWindow(
    this._settings, {
    this._shutdownBudget = const Duration(seconds: 3),
  });

  static final Logger _log = Logger('shell');

  /// The settings key the geometry is stored under.
  static const String settingsKey = 'windowBounds';

  final SettingsStore _settings;

  /// Coalesces the flurry of resize events a drag produces into one write.
  Timer? _pending;

  /// What to release on the way out, run behind the hidden window.
  ///
  /// The provider graph, in practice, and the reason this is assigned rather
  /// than passed to the constructor: the window is opened before the container
  /// exists, because its placement comes from the settings store and it has to
  /// be up before the first frame.
  ///
  /// Why the close path is where it belongs: `destroy` hands the process to
  /// its own teardown, and everything the application holds natively — a
  /// libmpv instance with an output device open, above all — is released
  /// there, at the slowest possible moment and with the window still on
  /// screen. Released here it is the same work done while the isolate is
  /// still alive and the owner is no longer looking at it.
  FutureOr<void> Function()? onClosing;

  /// How long the close path is given before the window goes regardless.
  final Duration _shutdownBudget;

  /// Whether the close is already under way.
  bool _closing = false;

  /// The last geometry the window had while neither maximized nor minimized,
  /// which is what is recorded beside a maximized window.
  Rect? _restored;

  /// Sizes the window, restores where it was, and shows it.
  Future<void> open() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(Breakpoint.minimumWindowSize);

    // What makes [onWindowClose] arrive at all. Without it the platform closes
    // the window and no listener runs, so the geometry of a window that was
    // moved and then closed inside the half second [_scheduleWrite] waits was
    // simply lost — and this class's own close path was unreachable code.
    //
    // The trade it makes is that closing the window becomes this class's job:
    // see [_finish], which destroys it whatever happens to the write.
    await windowManager.setPreventClose(true);

    final stored = _read();
    final bounds = stored?.bounds;
    _restored = bounds;

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: bounds?.size ?? Breakpoint.defaultWindowSize,
        // Centred when there is nothing stored, and at the stored position
        // when there is — `setBounds` below is what actually places it, since
        // the options only carry a size.
        center: bounds == null,
      ),
      () async {
        // Placed first even when it is about to be maximized: that is the
        // rectangle the restore button brings it back to.
        if (bounds != null) await windowManager.setBounds(bounds);
        // Maximized unless the owner said otherwise by leaving it that way,
        // and before it is shown, so it appears at its full size rather than
        // drawing once at the normal one and jumping.
        if (stored?.maximized ?? true) await windowManager.maximize();
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
  void onWindowMaximize() => _scheduleWrite();

  @override
  void onWindowUnmaximize() => _scheduleWrite();

  @override
  void onWindowClose() => unawaited(_finish());

  /// Stops listening, having written where the window ended up.
  ///
  /// [placement] is the geometry to record, for a caller that had to read it
  /// first. The close path did: it hides the window before it writes
  /// anything, and a hidden window is not a thing to ask where it is.
  Future<void> close({WindowPlacement? placement}) async {
    _stopListening();
    await _write(placement);
  }

  void _stopListening() {
    _pending?.cancel();
    windowManager.removeListener(this);
  }

  /// Takes the window off screen, records where it was, releases what the
  /// application holds, and quits.
  ///
  /// The order is the whole of this method, and Windows is what sets it.
  /// There `destroy` is `PostQuitMessage`: it ends the runner's message loop
  /// and returns, which leaves the window standing — painted, and no longer
  /// pumping messages — for the whole of the Flutter engine teardown that
  /// follows as the process unwinds. Everything between the owner's click and
  /// the end of that teardown is time an application spends looking like it
  /// did not hear the click, so the window goes first and the rest happens
  /// behind it.
  ///
  /// [_shutdownBudget] and the `finally` are the same idea said twice:
  /// [WindowManager.setPreventClose] means nothing closes this window but this
  /// method, so work that threw — or that hung on a settings store or an audio
  /// device that could not be reached — would leave an owner with an
  /// application they cannot quit. None of it is worth that.
  Future<void> _finish() async {
    // A second close event — two clicks on the button before the first hide
    // lands — would run the release a second time, and what it releases is
    // not all of it built to be released twice.
    if (_closing) return;
    _closing = true;

    try {
      await _shutDown().timeout(_shutdownBudget);
    } on Object catch (error) {
      _log.warning('the shutdown did not finish', error);
    } finally {
      await windowManager.destroy();
    }
  }

  Future<void> _shutDown() async {
    final placement = await _measure();

    await windowManager.hide();

    // Nothing measured — a minimized window — is nothing to record. Handed to
    // [close], it would be measured again, from the hidden window.
    _stopListening();
    if (placement != null) await _write(placement);

    await onClosing?.call();
  }

  /// Where the window is and whether it is maximized, or `null` where there is
  /// nothing worth recording.
  ///
  /// Read before the window is hidden, so what gets recorded is where the
  /// owner left it rather than whatever a hidden window reports — which is the
  /// last rectangle on Windows and rather less than that on GTK.
  ///
  /// A minimized window answers `null`: what Windows reports for one is a
  /// stub parked at -32000, and what it was before it was minimized is
  /// already recorded.
  Future<WindowPlacement?> _measure() async {
    try {
      if (await windowManager.isMinimized()) return null;
      if (await windowManager.isMaximized()) {
        return WindowPlacement(bounds: _restored, maximized: true);
      }

      final bounds = await windowManager.getBounds();
      _restored = bounds;

      return WindowPlacement(bounds: bounds, maximized: false);
    } on Object catch (error) {
      _log.warning('the window geometry could not be measured', error);

      return null;
    }
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

  /// Records [placement], measuring it itself where the caller had none.
  Future<void> _write([WindowPlacement? placement]) async {
    try {
      placement ??= await _measure();
      if (placement == null) return;

      final bounds = placement.bounds;
      await _settings.setString(
        settingsKey,
        jsonEncode({
          if (bounds != null) ...{
            'x': bounds.left,
            'y': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
          },
          'maximized': placement.maximized,
        }),
      );
    } on Object catch (error) {
      _log.warning('the window geometry could not be saved', error);
    }
  }

  /// The stored placement, or `null` where there is none worth using.
  ///
  /// A document written before the maximized flag existed carries no
  /// `maximized`, and reads as maximized: that is the default, and such a
  /// document only ever recorded where the window was, not how the owner
  /// wanted it opened.
  WindowPlacement? _read() {
    final stored = _settings.getString(settingsKey);
    if (stored == null) return null;

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;

      return WindowPlacement(
        bounds: _boundsFrom(decoded),
        maximized: decoded['maximized'] as bool? ?? true,
      );
    } on Object catch (error) {
      _log.warning('the window geometry could not be read', error);

      return null;
    }
  }

  /// The rectangle in [decoded], or `null` where there is none worth using.
  static Rect? _boundsFrom(Map<String, dynamic> decoded) {
    final x = (decoded['x'] as num?)?.toDouble();
    final y = (decoded['y'] as num?)?.toDouble();
    final width = (decoded['width'] as num?)?.toDouble();
    final height = (decoded['height'] as num?)?.toDouble();
    if (x == null || y == null || width == null || height == null) return null;

    // A window smaller than the minimum is geometry written by a version with
    // a different floor, or by a window manager that ignored one. It is
    // discarded rather than clamped: half-honouring stored geometry puts the
    // window somewhere the owner never left it.
    if (width < Breakpoint.minimumWindowSize.width ||
        height < Breakpoint.minimumWindowSize.height) {
      return null;
    }

    return Rect.fromLTWH(x, y, width, height);
  }
}

/// Where the window is, as it is recorded between runs.
class WindowPlacement {
  /// Creates a placement.
  const WindowPlacement({required this.maximized, this.bounds});

  /// The window's normal geometry — where it goes when it is not maximized —
  /// or `null` where none is known.
  final Rect? bounds;

  /// Whether it is maximized.
  final bool maximized;
}
