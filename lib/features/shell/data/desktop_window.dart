import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

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
class DesktopWindow {
  /// Creates the placement over [settings].
  ///
  /// [window] answers the application's native window, and is a seam for the
  /// tests, which run with no window and stand a recording one in its place.
  /// [shutdownBudget] is a seam for the test that asserts the window closes
  /// even when the release behind it never finishes. Nothing else passes
  /// either.
  DesktopWindow(
    this._settings, {
    Window? Function()? window,
    this._shutdownBudget = const Duration(seconds: 3),
  }) : _lookUp = window ?? WindowManager.instance.getCurrent;

  static final Logger _log = Logger('shell');

  /// The settings key the geometry is stored under.
  static const String settingsKey = 'windowBounds';

  final SettingsStore _settings;

  /// Where [open] finds the window.
  final Window? Function() _lookUp;

  /// The application's window, once [open] has found it.
  ///
  /// Kept rather than looked up at every call: each lookup makes a new native
  /// wrapper, and the listener [open] registers lives on this one.
  Window? _window;

  /// Coalesces the flurry of resize events a drag produces into one write.
  Timer? _pending;

  /// Whether the geometry is no longer being followed: the close path has
  /// recorded where the window was, and nothing after it may overwrite that.
  bool _stopped = false;

  /// What to release on the way out, run behind the hidden window.
  ///
  /// The provider graph, in practice, and the reason this is assigned rather
  /// than passed to the constructor: the window is opened before the container
  /// exists, because its placement comes from the settings store and it has to
  /// be up before the first frame.
  ///
  /// Why the close path is where it belongs: closing the last window hands
  /// the process to its own teardown, and everything the application holds
  /// natively — a libmpv instance with an output device open, above all — is
  /// released there, at the slowest possible moment and with the window still
  /// on screen. Released here it is the same work done while the isolate is
  /// still alive and the owner is no longer looking at it.
  FutureOr<void> Function()? onClosing;

  /// How long the close path is given before the window goes regardless.
  final Duration _shutdownBudget;

  /// Whether the close is already under way.
  bool _closing = false;

  /// Whether the close requests from here on are this class's own, the one
  /// that ends the application, and are to be let through.
  bool _quitting = false;

  /// The last geometry the window had while neither maximized nor minimized,
  /// which is what is recorded beside a maximized window.
  Rect? _restored;

  /// Sizes the window, restores where it was, and shows it.
  Future<void> open() async {
    final window = _window ??= _lookUp();
    if (window == null) {
      _log.warning('there is no window to place');

      return;
    }

    window.minimumSize = Breakpoint.minimumWindowSize.toNative();

    // What makes the close come here at all. Every request to close the
    // window — its title bar's button, the window manager's, the update
    // hand-off's [WindowShutdown] — reaches the window's listeners first, and
    // [_onEvent] refuses it and runs [_finish] instead. Without that the
    // geometry of a window that was moved and then closed inside the half
    // second [_scheduleWrite] waits is simply lost, and this class's own close
    // path is unreachable code.
    //
    // The trade it makes is that closing the window becomes this class's job:
    // see [_finish], which closes it whatever happens to the write.
    window.addListener(_onEvent);

    final stored = _read();
    final bounds = stored?.bounds;
    _restored = bounds;

    window.setSize(
      (bounds?.size ?? Breakpoint.defaultWindowSize).toNative(),
      false,
    );
    // Centred when there is nothing stored, and placed where it was when
    // there is — even when it is about to be maximized: that is the rectangle
    // the restore button brings it back to.
    if (bounds == null) {
      window.center();
    } else {
      window.bounds = bounds.toNative();
    }
    // Maximized unless the owner said otherwise by leaving it that way, and
    // before it is shown, so it appears at its full size rather than drawing
    // once at the normal one and jumping.
    if (stored?.maximized ?? true) window.maximize();
    window.show();
    window.focus();
  }

  void _onEvent(WindowEvent event) {
    switch (event) {
      case WindowCloseRequestedEvent(:final request):
        // The close [_quit] asks for goes through, and so does anything after
        // it: the application is on its way out.
        if (_quitting) return;
        request.cancel();
        unawaited(_finish());
      // A restore is the end of a maximize as well as of a minimize: the
      // platform reports the two the same way.
      case WindowResizedEvent() ||
          WindowMovedEvent() ||
          WindowMaximizedEvent() ||
          WindowRestoredEvent():
        _scheduleWrite();
      default:
        break;
    }
  }

  /// Stops following the window, having written where it ended up.
  ///
  /// [placement] is the geometry to record, for a caller that had to read it
  /// first. The close path did: it hides the window before it writes
  /// anything, and a hidden window is not a thing to ask where it is.
  Future<void> close({WindowPlacement? placement}) async {
    _stopListening();
    await _write(placement);
  }

  /// Stops the geometry writes. The close requests are still answered: the
  /// listener stays for as long as the window does, because without it a
  /// close would no longer come through [_finish].
  void _stopListening() {
    _stopped = true;
    _pending?.cancel();
  }

  /// Takes the window off screen, records where it was, releases what the
  /// application holds, and quits.
  ///
  /// The order is the whole of this method, and Windows is what sets it.
  /// There the last window closing ends the runner's message loop, and the
  /// process then stands for the whole of the Flutter engine teardown that
  /// follows as it unwinds. Everything between the owner's click and the end
  /// of that teardown is time an application spends looking like it did not
  /// hear the click, so the window goes first and the rest happens behind it.
  ///
  /// [_shutdownBudget] and the `finally` are the same idea said twice: the
  /// listener [open] registers means nothing closes this window but this
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
      _quit();
    }
  }

  /// Closes the window for good, which on both desktops ends the application.
  ///
  /// The close goes back through [_onEvent], which lets this one pass. Where
  /// the platform will not close the window at all, the process ends without
  /// it: a window that stays is an application the owner cannot quit, and
  /// everything worth releasing has been by now.
  void _quit() {
    _quitting = true;

    var closed = false;
    try {
      closed = _window?.close() ?? false;
    } on Object catch (error) {
      _log.warning('the window could not be closed', error);
    }

    if (!closed) exit(0);
  }

  Future<void> _shutDown() async {
    final placement = await _measure();

    _window?.hide();

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
      final window = _window;
      if (window == null || window.isMinimized) return null;
      if (window.isMaximized) {
        return WindowPlacement(bounds: _restored, maximized: true);
      }

      final bounds = window.bounds.toRect();
      _restored = bounds;

      return WindowPlacement(bounds: bounds, maximized: false);
    } on Object catch (error) {
      _log.warning('the window geometry could not be measured', error);

      return null;
    }
  }

  void _scheduleWrite() {
    if (_stopped) return;
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
