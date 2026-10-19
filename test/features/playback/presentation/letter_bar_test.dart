import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/presentation/letter_bar.dart';

import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The strip of letters beside a long list: what a tap and a drag ask for.
void main() {
  Future<List<String>> pumpBar(
    WidgetTester tester, {
    Set<String> available = const {'#', 'A', 'B', 'C', 'M', 'Z'},
  }) async {
    final asked = <String>[];
    await tester.pumpHarness(
      Harness(),
      Scaffold(
        body: Row(
          children: [
            const Expanded(child: SizedBox()),
            LetterBar(available: available, onLetter: asked.add),
          ],
        ),
      ),
    );

    return asked;
  }

  testWidgets('GivenTheBar_WhenItIsShown_ThenItHoldsTheHashAndEveryLetter', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.text('#'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets(
    'GivenALetterWithNamesUnderIt_WhenItIsTapped_ThenThatLetterIsAskedFor',
    (tester) async {
      final asked = await pumpBar(tester);

      await tester.tap(find.text('M'));
      await tester.pumpAndSettle();

      expect(asked, ['M']);
    },
  );

  testWidgets(
    'GivenALetterWithNothingUnderIt_WhenItIsTapped_ThenNothingIsAskedFor',
    (tester) async {
      final asked = await pumpBar(tester);

      await tester.tap(find.text('Q'));
      await tester.pumpAndSettle();

      expect(asked, isEmpty);
    },
  );

  testWidgets(
    'GivenTheBar_WhenTheOwnerDragsDownIt_ThenEachLetterWithNamesIsAskedForOnceAsItIsPassed',
    (tester) async {
      final asked = await pumpBar(tester);
      final start = tester.getCenter(find.text('A'));
      final end = tester.getCenter(find.text('D'));

      final gesture = await tester.startGesture(start);
      await tester.pump();
      for (var step = 1; step <= 10; step++) {
        await gesture.moveTo(Offset.lerp(start, end, step / 10)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(asked, ['A', 'B', 'C']);
    },
  );

  testWidgets(
    'GivenTheOwnerIsDragging_WhenTheirFingerIsOnALetter_ThenALargeBubbleShowsIt',
    (tester) async {
      await pumpBar(tester);
      final start = tester.getCenter(find.text('A'));
      final onM = tester.getCenter(find.text('M'));

      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveTo(Offset.lerp(start, onM, 0.5)!);
      await tester.pump();
      await gesture.moveTo(onM);
      await tester.pump();

      expect(find.byKey(LetterBar.bubbleKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LetterBar.bubbleKey),
          matching: find.text('M'),
        ),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(LetterBar.bubbleKey), findsNothing);
    },
  );
}
