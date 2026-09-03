import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/core/theme/app_theme.dart';
import 'package:orpheus/core/theme/breakpoints.dart';

import 'test_container.dart';

/// The window a widget test is laid out in, unless it says otherwise.
///
/// A desktop-sized surface, because that is the arrangement with the most in
/// it: the rail, the search field and the full transport are all present, and
/// a test that wanted the phone arrangement asks for [phoneWindow].
const Size desktopWindow = Size(1400, 900);

/// A phone-sized surface, for the tests about the other arrangement.
const Size phoneWindow = Size(411, 820);

/// Puts [child] on screen inside [harness]'s provider graph.
///
/// One helper rather than a `MaterialApp` built in each test, so that every
/// widget test has the same themes, the same locale and the same window — and
/// so that a test never accidentally runs against the real settings store or
/// the native playback engine.
extension PumpHarness on WidgetTester {
  /// Renders [child] and settles.
  /// [reduceMotion] is on by default, and is what makes `pumpAndSettle`
  /// usable: the sound bars run a ticker for as long as music is playing, and
  /// a tree with a ticker in it never settles. It also means the reduced-motion
  /// path — the one an owner who has asked the system for less animation
  /// actually sees — is the one the widget tests exercise.
  Future<void> pumpHarness(
    Harness harness,
    Widget child, {
    Size window = desktopWindow,
    Locale locale = const Locale('en'),
    bool reduceMotion = true,
  }) async {
    view.physicalSize = window;
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('pt', 'BR')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, built) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: built!,
          ),
          home: child,
        ),
      ),
    );

    await pumpAndSettle();
  }

  /// Which arrangement the current window resolves to.
  Breakpoint get breakpoint => Breakpoint.of(view.physicalSize.width);
}
