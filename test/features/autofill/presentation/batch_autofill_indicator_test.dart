import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/autofill/application/batch_autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/presentation/batch_autofill_indicator.dart';
import 'package:orpheus/features/autofill/presentation/batch_autofill_screen.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/shell/presentation/shell_screen.dart';

import '../../../support/batch_autofill_fixtures.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The shell's indicator: a batch autofill's progress, or how many records
/// still need the owner, and the way back to the batch screen.
void main() {
  const artistOnly = {AutofillField.artist};

  BatchAutofillController controllerOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider.notifier);

  Future<void> show(
    WidgetTester tester,
    Harness harness, {
    Size window = desktopWindow,
  }) => tester.pumpHarness(harness, const ShellScreen(), window: window);

  /// Runs [library] as a batch to its end.
  Future<void> finish(Harness harness, List<MusicEntry> library) async {
    final controller = controllerOf(harness);
    await controller.start(planBatch(library, library), artistOnly);
    await controller.settled;
  }

  /// A batch of two records held on MusicBrainz, so it is running.
  Future<Harness> aRunningBatch() async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = batchHarness(library);
    final gate = Completer<void>();
    harness.metadata.hold = gate.future;
    addTearDown(() => gate.isCompleted ? null : gate.complete());
    await controllerOf(harness).start(planBatch(library, library), artistOnly);

    return harness;
  }

  /// A finished batch where Beta, a bootleg, is kept for the owner.
  Future<Harness> aFinishedBatchWithADoubt() async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = batchHarness(
      library,
      releases: {
        'Alpha': releaseOf('Alpha'),
        'Beta': releaseOf('Beta', status: 'Bootleg'),
      },
    );
    await finish(harness, library);

    return harness;
  }

  testWidgets('GivenNoBatch_WhenShellShown_ThenNoIndicator', (tester) async {
    final harness = batchHarness(albumOf('Alpha'));

    await show(tester, harness);

    expect(find.byType(BatchAutofillIndicator), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
    expect(find.textContaining('Autofill'), findsNothing);
  });

  testWidgets('GivenARunningBatch_WhenShellShown_ThenAutofillingDoneOfTotal', (
    tester,
  ) async {
    final harness = await aRunningBatch();

    await show(tester, harness);

    expect(find.text('Autofilling 0/2'), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high_outlined), findsOneWidget);
  });

  testWidgets('GivenPaused_WhenShown_ThenAutofillPaused', (tester) async {
    final library = [
      ...albumOf('Alpha'),
      ...albumOf('Beta'),
      ...albumOf('Gamma'),
    ];
    final harness = batchHarness(library);
    harness.metadata.failure = MetadataSourceFailure.unreachable;
    await finish(harness, library);
    expect(
      harness.read(batchAutofillControllerProvider).stage,
      BatchStage.paused,
    );

    await show(tester, harness);

    expect(find.text('Autofill paused'), findsOneWidget);
  });

  testWidgets('GivenFinishedWithDoubtfulAndSeen_WhenShown_ThenNeedYouCount', (
    tester,
  ) async {
    final harness = await aFinishedBatchWithADoubt();
    controllerOf(harness).markSeen();

    await show(tester, harness);

    expect(find.text('1 needs you'), findsOneWidget);
    expect(find.text('Autofill done'), findsNothing);
  });

  testWidgets('GivenFinishedNotSeenWithDoubtful_WhenShown_ThenNeedYouCount', (
    tester,
  ) async {
    final harness = await aFinishedBatchWithADoubt();

    await show(tester, harness);

    expect(find.text('1 needs you'), findsOneWidget);
    expect(find.text('Autofill done'), findsNothing);
  });

  testWidgets(
    'GivenFinishedNotSeenNothingDoubtful_WhenShown_ThenAutofillDone',
    (tester) async {
      final library = albumOf('Alpha');
      final harness = batchHarness(library);
      await finish(harness, library);

      await show(tester, harness);

      expect(find.text('Autofill done'), findsOneWidget);
    },
  );

  testWidgets('GivenFinishedSeenNothingDoubtful_WhenShown_ThenNoIndicator', (
    tester,
  ) async {
    final library = albumOf('Alpha');
    final harness = batchHarness(library);
    await finish(harness, library);
    controllerOf(harness).markSeen();

    await show(tester, harness);

    expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
    expect(find.text('Autofill done'), findsNothing);
  });

  testWidgets('GivenTheIndicator_WhenTapped_ThenTheBatchScreenOpens', (
    tester,
  ) async {
    final harness = await aRunningBatch();
    await show(tester, harness);
    expect(find.byType(BatchAutofillScreen), findsNothing);

    await tester.tap(find.text('Autofilling 0/2'));
    await tester.pumpAndSettle();

    expect(find.byType(BatchAutofillScreen), findsOneWidget);
  });

  testWidgets('GivenAPhone_WhenRunning_ThenAnIconWithABadge', (tester) async {
    final harness = await aRunningBatch();

    await show(tester, harness, window: phoneWindow);

    expect(find.text('Autofilling 0/2'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BatchAutofillIndicator),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect((badge.label! as Text).data, '0/2');
    expect(find.byTooltip('Autofilling 0/2'), findsOneWidget);
  });

  testWidgets('GivenAPhone_WhenFinishedWithDoubtful_ThenTheBadgeCountsThem', (
    tester,
  ) async {
    final harness = await aFinishedBatchWithADoubt();
    controllerOf(harness).markSeen();

    await show(tester, harness, window: phoneWindow);

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect((badge.label! as Text).data, '1');
    expect(find.byTooltip('1 needs you'), findsOneWidget);
  });
}
