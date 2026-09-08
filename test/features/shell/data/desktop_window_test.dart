import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/shell/data/desktop_window.dart';

/// The close path: what the owner sees first, and what cannot hold it up.
///
/// The order these calls go out in is the whole of the fix they guard.
/// `destroy` on Windows is `PostQuitMessage` — it ends the runner's message
/// loop and returns, leaving the window on screen for the whole of the engine
/// teardown that follows — so a window hidden after that work rather than
/// before it is a window that sits there, painted and frozen, for as long as
/// the teardown takes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWindowChannel channel;

  setUp(() => channel = FakeWindowChannel()..install());
  tearDown(() => channel.remove());

  test(
    'GivenAnOpenWindow_WhenTheOwnerClosesIt_ThenItIsHiddenBeforeAnythingElse',
    () async {
      final window = DesktopWindow(InMemorySettingsStore());

      window.onWindowClose();
      await pumpEventQueue();

      // Read where it was first — a hidden window is not a thing to ask — and
      // then off the screen, before the settings write and before the quit.
      expect(channel.calls, ['getBounds', 'hide', 'destroy']);
    },
  );

  test(
    'GivenTheOwnerClosesTheWindow_WhenItIsHidden_ThenTheGeometryLeftOnScreenIsWhatIsStored',
    () async {
      final settings = InMemorySettingsStore();
      // What a window manager may answer once the window is gone. Nothing here
      // should ever record it.
      channel.boundsAfterHide = Rect.zero;

      final window = DesktopWindow(settings);

      window.onWindowClose();
      await pumpEventQueue();

      final stored =
          jsonDecode(settings.getString(DesktopWindow.settingsKey)!)
              as Map<String, dynamic>;
      expect(stored['x'], 120.0);
      expect(stored['y'], 80.0);
      expect(stored['width'], 1024.0);
      expect(stored['height'], 720.0);
    },
  );

  test(
    'GivenSomethingToRelease_WhenTheWindowIsClosed_ThenItIsReleasedBehindTheHiddenWindow',
    () async {
      var releasedAfter = <String>[];
      final window = DesktopWindow(InMemorySettingsStore())
        ..onClosing = () => releasedAfter = [...channel.calls];

      window.onWindowClose();
      await pumpEventQueue();

      // Released with the window already gone and before the quit, which is
      // the point of doing it here at all: the same teardown, done while the
      // isolate is alive and the owner is no longer looking.
      expect(releasedAfter, contains('hide'));
      expect(releasedAfter, isNot(contains('destroy')));
      expect(channel.calls, contains('destroy'));
    },
  );

  test(
    'GivenAReleaseThatNeverFinishes_WhenTheWindowIsClosed_ThenItStillQuits',
    () async {
      // `setPreventClose` means nothing closes this window but this class, so
      // a release that hangs on an audio device that will not answer would
      // otherwise be an application the owner cannot quit.
      final window = DesktopWindow(
        InMemorySettingsStore(),
        shutdownBudget: const Duration(milliseconds: 20),
      )..onClosing = () => Completer<void>().future;

      window.onWindowClose();
      // Long enough for the budget above to run out, which is the only thing
      // that can end this close.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpEventQueue();

      expect(channel.calls, contains('destroy'));
    },
  );

  test(
    'GivenTwoClicksOnTheCloseButton_WhenBothArrive_ThenTheReleaseRunsOnce',
    () async {
      var releases = 0;
      final window = DesktopWindow(InMemorySettingsStore())
        ..onClosing = () => releases++;

      window
        ..onWindowClose()
        ..onWindowClose();
      await pumpEventQueue();

      expect(releases, 1);
    },
  );

  test(
    'GivenAStoreThatWillNotWrite_WhenTheWindowIsClosed_ThenItStillQuits',
    () async {
      final window = DesktopWindow(UnwritableSettingsStore());

      window.onWindowClose();
      await pumpEventQueue();

      expect(channel.calls, contains('destroy'));
    },
  );
}

/// Stands in for the platform side of `window_manager`, recording what it was
/// asked to do and in what order.
class FakeWindowChannel {
  static const MethodChannel _channel = MethodChannel('window_manager');

  /// The methods invoked, in the order they went out.
  final List<String> calls = [];

  /// Where the window is until it is hidden.
  Rect bounds = const Rect.fromLTWH(120, 80, 1024, 720);

  /// What a `getBounds` after the hide answers, where a test wants that to be
  /// something other than the truth.
  Rect? boundsAfterHide;

  bool _hidden = false;

  /// Binds this in place of the platform.
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);

          switch (call.method) {
            case 'hide':
              _hidden = true;

              return null;
            case 'getBounds':
              final rect = _hidden ? boundsAfterHide ?? bounds : bounds;

              return <String, dynamic>{
                'x': rect.left,
                'y': rect.top,
                'width': rect.width,
                'height': rect.height,
              };
            default:
              return null;
          }
        });
  }

  /// Unbinds it.
  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

/// A settings store that refuses every write.
class UnwritableSettingsStore extends InMemorySettingsStore {
  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('the settings could not be written');
}
