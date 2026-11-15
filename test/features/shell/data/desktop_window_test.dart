import 'dart:async';
import 'dart:convert';

import 'dart:ui' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/core/theme/breakpoints.dart';
import 'package:orpheus/features/shell/data/desktop_window.dart';
import 'package:window_manager/window_manager.dart';

/// The close path: what the owner sees first, and what cannot hold it up.
///
/// The order these calls go out in is the whole of the fix they guard. Closing
/// the last window on Windows ends the runner's message loop and leaves the
/// process standing for the whole of the engine teardown that follows, so a
/// window hidden after that work rather than before it is a window that sits
/// there, painted and frozen, for as long as the teardown takes.
void main() {
  late FakeWindow native;

  setUp(() => native = FakeWindow());

  /// Opens a window over [settings], un-maximizes it as the owner would, and
  /// forgets what opening it asked for, so a test sees only the calls that
  /// come after.
  Future<DesktopWindow> open(
    InMemorySettingsStore settings, {
    Duration shutdownBudget = const Duration(seconds: 3),
    FutureOr<void> Function()? onClosing,
  }) async {
    final window = DesktopWindow(
      settings,
      window: () => native,
      shutdownBudget: shutdownBudget,
    )..onClosing = onClosing;

    await window.open();
    native
      ..maximized = false
      ..calls.clear();

    return window;
  }

  test(
    'GivenAnOpenWindow_WhenTheOwnerClosesIt_ThenItIsHiddenBeforeAnythingElse',
    () async {
      await open(InMemorySettingsStore());

      final closedAtOnce = await native.requestClose();
      await pumpEventQueue();

      // Refused at first: the window is this class's to close. Read where it
      // was — a hidden window is not a thing to ask — and then off the
      // screen, before the settings write and before the close that ends the
      // application, which is let through.
      expect(closedAtOnce, isFalse);
      expect(native.calls, ['isMinimized', 'isMaximized', 'bounds', 'hide', 'close']);
      expect(native.closed, isTrue);
    },
  );

  test(
    'GivenTheOwnerClosesTheWindow_WhenItIsHidden_ThenTheGeometryLeftOnScreenIsWhatIsStored',
    () async {
      final settings = InMemorySettingsStore();
      // What a window manager may answer once the window is gone. Nothing here
      // should ever record it.
      native.boundsAfterHide = Rect.zero;
      await open(settings);

      await native.requestClose();
      await pumpEventQueue();

      final stored =
          jsonDecode(settings.getString(DesktopWindow.settingsKey)!)
              as Map<String, dynamic>;
      expect(stored['x'], 120.0);
      expect(stored['y'], 80.0);
      expect(stored['width'], 1024.0);
      expect(stored['height'], 720.0);
      expect(stored['maximized'], isFalse);
    },
  );

  test(
    'GivenSomethingToRelease_WhenTheWindowIsClosed_ThenItIsReleasedBehindTheHiddenWindow',
    () async {
      var releasedAfter = <String>[];
      await open(
        InMemorySettingsStore(),
        onClosing: () => releasedAfter = [...native.calls],
      );

      await native.requestClose();
      await pumpEventQueue();

      // Released with the window already gone and before the close, which is
      // the point of doing it here at all: the same teardown, done while the
      // isolate is alive and the owner is no longer looking.
      expect(releasedAfter, contains('hide'));
      expect(releasedAfter, isNot(contains('close')));
      expect(native.closed, isTrue);
    },
  );

  test(
    'GivenAReleaseThatNeverFinishes_WhenTheWindowIsClosed_ThenItStillQuits',
    () async {
      // Nothing closes this window but this class, so a release that hangs on
      // an audio device that will not answer would otherwise be an
      // application the owner cannot quit.
      await open(
        InMemorySettingsStore(),
        shutdownBudget: const Duration(milliseconds: 20),
        onClosing: () => Completer<void>().future,
      );

      await native.requestClose();
      // Long enough for the budget above to run out, which is the only thing
      // that can end this close.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpEventQueue();

      expect(native.closed, isTrue);
    },
  );

  test(
    'GivenTwoClicksOnTheCloseButton_WhenBothArrive_ThenTheReleaseRunsOnce',
    () async {
      var releases = 0;
      final release = Completer<void>();
      await open(
        InMemorySettingsStore(),
        onClosing: () {
          releases++;

          return release.future;
        },
      );

      await native.requestClose();
      final second = await native.requestClose();
      release.complete();
      await pumpEventQueue();

      // The second click is refused as the first was: the window still goes
      // when the release is done, and not before.
      expect(second, isFalse);
      expect(releases, 1);
      expect(native.closed, isTrue);
    },
  );

  test(
    'GivenAStoreThatWillNotWrite_WhenTheWindowIsClosed_ThenItStillQuits',
    () async {
      await open(UnwritableSettingsStore());

      await native.requestClose();
      await pumpEventQueue();

      expect(native.closed, isTrue);
    },
  );

  test(
    'GivenAWindowTheOwnerMoved_WhenItSettles_ThenWhereItWasLeftIsStored',
    () async {
      final settings = InMemorySettingsStore();
      await open(settings);
      native.current = const Rect.fromLTWH(300, 200, 1000, 700);

      await native.emit(
        WindowMovedEvent(
          windowId: FakeWindow.windowId,
          newPosition: const Offset(300, 200).toNative(),
        ),
      );
      // Past the half second a drag's events are coalesced over.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final stored =
          jsonDecode(settings.getString(DesktopWindow.settingsKey)!)
              as Map<String, dynamic>;
      expect(stored['x'], 300.0);
      expect(stored['width'], 1000.0);
      expect(stored['maximized'], isFalse);
    },
  );

  group('maximized by default', () {
    String placement({required bool? maximized}) => jsonEncode({
      'x': 200.0,
      'y': 100.0,
      'width': 1100.0,
      'height': 800.0,
      'maximized': ?maximized,
    });

    /// Opens a window over [settings], keeping what opening it asked for.
    Future<DesktopWindow> openFresh(InMemorySettingsStore settings) async {
      final window = DesktopWindow(settings, window: () => native);
      await window.open();

      return window;
    }

    test(
      'GivenNothingStored_WhenTheWindowOpens_ThenItIsCentredAtTheDefaultSizeAndMaximized',
      () async {
        await openFresh(InMemorySettingsStore());

        expect(native.minimumSizeSet, Breakpoint.minimumWindowSize);
        expect(native.lastSize, Breakpoint.defaultWindowSize);
        expect(native.calls, isNot(contains('setBounds')));
        expect(native.calls, containsAllInOrder(['center', 'maximize', 'show']));
      },
    );

    test(
      'GivenGeometryStoredBeforeTheFlagExisted_WhenTheWindowOpens_ThenItIsMaximized',
      () async {
        final settings = InMemorySettingsStore();
        await settings.setString(
          DesktopWindow.settingsKey,
          placement(maximized: null),
        );

        await openFresh(settings);

        // Placed at its normal geometry first — that is where the restore
        // button takes it — then maximized, and only then shown.
        expect(native.calls, containsAllInOrder(['setBounds', 'maximize', 'show']));
      },
    );

    test(
      'GivenAWindowLeftMaximized_WhenItOpens_ThenItIsMaximized',
      () async {
        final settings = InMemorySettingsStore();
        await settings.setString(
          DesktopWindow.settingsKey,
          placement(maximized: true),
        );

        await openFresh(settings);

        expect(native.calls, containsAllInOrder(['maximize', 'show']));
      },
    );

    test(
      'GivenAWindowTheOwnerLeftUnmaximized_WhenItOpens_ThenItOpensWhereTheyLeftIt',
      () async {
        final settings = InMemorySettingsStore();
        await settings.setString(
          DesktopWindow.settingsKey,
          placement(maximized: false),
        );

        await openFresh(settings);

        expect(native.calls, isNot(contains('maximize')));
        expect(native.calls, isNot(contains('center')));
        expect(native.lastBounds, const Rect.fromLTWH(200, 100, 1100, 800));
      },
    );

    test(
      'GivenAMaximizedWindow_WhenItIsClosed_ThenItsNormalGeometryIsKept',
      () async {
        // A maximized window's own rectangle is the screen. Recording that
        // would leave the restore button nowhere to go back to.
        final settings = InMemorySettingsStore();
        await settings.setString(
          DesktopWindow.settingsKey,
          placement(maximized: true),
        );
        await openFresh(settings);
        native.current = const Rect.fromLTWH(0, 0, 2560, 1400);

        await native.requestClose();
        await pumpEventQueue();

        final stored =
            jsonDecode(settings.getString(DesktopWindow.settingsKey)!)
                as Map<String, dynamic>;
        expect(stored['maximized'], isTrue);
        expect(stored['x'], 200.0);
        expect(stored['width'], 1100.0);
      },
    );

    test(
      'GivenAMinimizedWindow_WhenItIsClosed_ThenWhatWasStoredIsKept',
      () async {
        // What Windows reports for a minimized window is a stub parked off
        // screen, and is nothing anyone wants the next launch to open at.
        final settings = InMemorySettingsStore();
        final before = placement(maximized: true);
        await settings.setString(DesktopWindow.settingsKey, before);
        await openFresh(settings);
        native
          ..minimized = true
          ..current = const Rect.fromLTWH(-32000, -32000, 160, 28);

        await native.requestClose();
        await pumpEventQueue();

        expect(settings.getString(DesktopWindow.settingsKey), before);
        expect(native.closed, isTrue);
      },
    );
  });
}

/// Stands in for the native window, recording what it was asked to do and in
/// what order, and closing the way the platform does: a request the
/// listeners hear first, and any of them may refuse.
///
/// Everything [DesktopWindow] does not use throws, so a call this does not
/// know about fails the test rather than passing it by doing nothing.
class FakeWindow implements Window {
  /// The id its events carry.
  static const int windowId = 1;

  /// The calls made, in the order they went out.
  final List<String> calls = [];

  /// Where the window is until it is hidden.
  Rect current = const Rect.fromLTWH(120, 80, 1024, 720);

  /// What [bounds] answers once the window is hidden, where a test wants that
  /// to be something other than the truth.
  Rect? boundsAfterHide;

  /// Whether it is maximized; [maximize] sets it.
  bool maximized = false;

  /// Whether it is minimized.
  bool minimized = false;

  /// The rectangle the last [bounds] assignment asked for.
  Rect? lastBounds;

  /// The size the last [setSize] asked for.
  Size? lastSize;

  /// The minimum size it was given.
  Size? minimumSizeSet;

  /// Whether a close request went through.
  bool closed = false;

  bool _hidden = false;

  final List<FutureOr<void> Function(WindowEvent)> _listeners = [];

  @override
  set minimumSize(value) => minimumSizeSet = value.toSize();

  @override
  void setSize(size, bool animate) {
    calls.add('setSize');
    lastSize = size.toSize();
  }

  @override
  void center() => calls.add('center');

  @override
  get bounds {
    calls.add('bounds');

    return (_hidden ? boundsAfterHide ?? current : current).toNative();
  }

  @override
  set bounds(value) {
    calls.add('setBounds');
    lastBounds = value.toRect();
    current = value.toRect();
  }

  @override
  void maximize() {
    calls.add('maximize');
    maximized = true;
  }

  @override
  bool get isMaximized {
    calls.add('isMaximized');

    return maximized;
  }

  @override
  bool get isMinimized {
    calls.add('isMinimized');

    return minimized;
  }

  @override
  void show() => calls.add('show');

  @override
  void focus() => calls.add('focus');

  @override
  void hide() {
    calls.add('hide');
    _hidden = true;
  }

  @override
  bool close() {
    calls.add('close');
    unawaited(requestClose());

    return true;
  }

  @override
  int addListener(callback) {
    _listeners.add(callback);

    return _listeners.length;
  }

  /// What the platform does when the window is asked to close — by its title
  /// bar's button, say: every listener hears the request, and it goes through
  /// unless one refuses it. Answers whether it went through.
  Future<bool> requestClose() async {
    final request = FakeCloseRequest();
    await emit(WindowCloseRequestedEvent(windowId: windowId, request: request));
    if (!request.cancelled) closed = true;

    return !request.cancelled;
  }

  /// Delivers [event] to every listener.
  Future<void> emit(WindowEvent event) async {
    for (final listener in [..._listeners]) {
      await listener(event);
    }
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeWindow: ${invocation.memberName}');
}

/// A close request a listener can refuse.
class FakeCloseRequest implements EventRequest {
  /// Whether a listener refused it.
  bool cancelled = false;

  @override
  bool cancel() {
    cancelled = true;

    return true;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeCloseRequest: ${invocation.memberName}');
}

/// A settings store that refuses every write.
class UnwritableSettingsStore extends InMemorySettingsStore {
  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('the settings could not be written');
}
