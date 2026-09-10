import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/presentation/sliding_text.dart';

/// A line that travels when it will not fit, and stands still when it will.
void main() {
  const short = 'Airbag';
  const long =
      'Everything In Its Right Place (Remastered Extended Album Version)';

  /// One line of [text] in a box [width] wide, with [reduceMotion] as the
  /// system's setting.
  Widget line(
    String text, {
    double width = 160,
    bool reduceMotion = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: SlidingText(text)),
        ),
      ),
    ),
  );

  /// Where the line has got to, from the left of the screen.
  double at(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dx;

  testWidgets(
    'GivenANameThatFitsItsBox_WhenItIsDrawn_ThenItDoesNotMove',
    (tester) async {
      await tester.pumpWidget(line(short));
      final start = at(tester, short);

      await tester.pump(SlidingText.pause * 2);
      await tester.pump(const Duration(seconds: 5));

      expect(at(tester, short), start);
      // Nothing is clipped, because nothing is hidden: a box that fits its
      // line gets an ordinary one.
      expect(
        find.descendant(
          of: find.byType(SlidingText),
          matching: find.byType(ClipRect),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'GivenANameTooLongForItsBox_WhenItRests_ThenItStartsFromTheBeginning',
    (tester) async {
      await tester.pumpWidget(line(long));
      final start = at(tester, long);

      // Within the pause at the start of the trip, where the name is held
      // still long enough to be read from its first word.
      await tester.pump(SlidingText.pause ~/ 2);

      expect(at(tester, long), start);
    },
  );

  testWidgets(
    'GivenANameTooLongForItsBox_WhenTheTripRuns_ThenItSlidesOutAndComesBack',
    (tester) async {
      await tester.pumpWidget(line(long));
      final start = at(tester, long);

      // Sampled across a whole trip rather than at moments worked out here:
      // how long a crossing takes is the length of the name divided by the
      // reading pace, and a test that hardcoded the answer would be asserting
      // the width of a font.
      var furthest = start;
      var returned = false;
      for (var step = 0; step < 480; step++) {
        await tester.pump(const Duration(milliseconds: 250));
        final now = at(tester, long);
        if (now < furthest) furthest = now;
        // Back where it started, after having been somewhere else: the trip
        // is out and back, not a loop that wraps the end of the name round to
        // its beginning.
        if (furthest < start && now == start) returned = true;
      }

      expect(furthest, lessThan(start), reason: 'the name never set off');
      expect(returned, isTrue, reason: 'the name never came back');

      // Left with nothing to travel, so no ticker is running at teardown.
      await tester.pumpWidget(line(short));
      await tester.pump();
    },
  );

  testWidgets(
    'GivenTheOwnerAskedForLessMotion_WhenTheNameIsTooLong_ThenItIsEllipsised',
    (tester) async {
      await tester.pumpWidget(line(long, reduceMotion: true));
      final start = at(tester, long);

      await tester.pump(SlidingText.pause * 3);

      expect(at(tester, long), start);
      expect(
        tester.widget<Text>(find.text(long)).overflow,
        TextOverflow.ellipsis,
      );
    },
  );
}
