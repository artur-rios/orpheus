import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/application/music_browse_controller.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';
import 'package:orpheus/features/playback/presentation/music_library_view.dart';
import 'package:orpheus/features/shell/presentation/shell_screen.dart';

import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The row above the library: the view switcher, shuffle, and the layout
/// switcher.
///
/// Together they want more width than a handset has. What that used to cost
/// was a segmented control squeezed until its own labels wrapped mid-word —
/// "Albu / ms" — so what these assert is that the three of them are laid out
/// in a way that gives the words room.
void main() {
  // An empty library, which is the state the controls were reported wrong in
  // and the one that leaves exactly one shuffle button on screen: the rows of
  // a populated library each carry one of their own.
  // Scoped to the music area: the playback bar carries a shuffle button of
  // its own, and this is not about that one.
  Finder inArea(Finder matching) => find.descendant(
    of: find.byType(MusicLibraryView),
    matching: matching,
  );

  Finder viewSwitcher() => inArea(find.byType(SegmentedButton<MusicView>));
  Finder layoutSwitcher() => inArea(find.byType(SegmentedButton<MusicLayout>));
  Finder shuffle() => inArea(find.widgetWithIcon(IconButton, Icons.shuffle));

  testWidgets(
    'GivenAPhoneSizedWindow_WhenTheMusicAreaIsShown_ThenNoViewLabelWraps',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, const ShellScreen(), window: phoneWindow);

      for (final label in ['Artists', 'Albums', 'Songs']) {
        final text = tester.renderObject<RenderBox>(
          find.descendant(
            of: viewSwitcher(),
            matching: find.text(label),
          ),
        );
        final oneLine = tester.renderObject<RenderBox>(find.text('Songs')).size;
        expect(
          text.size.height,
          lessThanOrEqualTo(oneLine.height),
          reason: '"$label" wrapped onto a second line',
        );
      }
    },
  );

  testWidgets(
    'GivenAPhoneSizedWindow_WhenTheMusicAreaIsShown_ThenTheViewSwitcherHasARowToItself',
    (tester) async {
      // What gives the labels their room: a third of the whole width each,
      // rather than a third of what the other two controls left over.
      final harness = Harness();

      await tester.pumpHarness(harness, const ShellScreen(), window: phoneWindow);

      expect(
        tester.getBottomLeft(viewSwitcher()).dy,
        lessThanOrEqualTo(tester.getTopLeft(shuffle()).dy),
      );
      expect(
        tester.getSize(viewSwitcher()).width,
        greaterThan(tester.getSize(layoutSwitcher()).width * 2),
      );
    },
  );

  testWidgets(
    'GivenADesktopSizedWindow_WhenTheMusicAreaIsShown_ThenTheThreeControlsShareOneRow',
    (tester) async {
      // The reflow is the phone tier's alone. A window with the width for one
      // row still gets one row.
      final harness = Harness();

      await tester.pumpHarness(harness, const ShellScreen());

      expect(
        tester.getCenter(viewSwitcher()).dy,
        closeTo(tester.getCenter(shuffle()).dy, 1),
      );
      expect(
        tester.getCenter(layoutSwitcher()).dy,
        closeTo(tester.getCenter(shuffle()).dy, 1),
      );
    },
  );
}
