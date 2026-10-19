import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/shell/presentation/preferences_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The *Your data* section of the Preferences, and what it says about an
/// export.
void main() {
  final library = [entry(id: 'a', title: 'Alpha')];

  Future<Harness> open(
    WidgetTester tester, {
    bool failPlaylists = false,
    bool failLibrary = false,
  }) async {
    final harness = Harness(library: library, now: DateTime(2026, 10, 18));
    if (failPlaylists) {
      harness.playlistStore.failRead = const FileSystemException('no access');
    }
    if (failLibrary) harness.catalogs.failOnRead = true;
    await tester.pumpHarness(harness, const _OpenPreferences());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return harness;
  }

  /// [text], as said inside the Preferences dialog rather than anywhere on
  /// the screen behind it, where its barrier would dim it.
  Finder said(String text) => find.descendant(
    of: find.byType(PreferencesDialog),
    matching: find.text(text),
  );

  Finder exportTile() => find.widgetWithText(ListTile, 'Export my data…');

  Future<void> tapExport(WidgetTester tester) async {
    await tester.ensureVisible(exportTile());
    await tester.pumpAndSettle();
    await tester.tap(exportTile());
  }

  testWidgets(
    'GivenThePreferences_WhenTheyOpen_ThenTheYourDataSectionOffersTheExport',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(exportTile());

      expect(find.text('Your data'), findsOneWidget);
      expect(exportTile(), findsOneWidget);
      expect(tester.widget<ListTile>(exportTile()).enabled, isTrue);
    },
  );

  testWidgets(
    'GivenTheOwnerChoosesAPlace_WhenTheyExport_ThenTheFileIsSavedAndTheDialogNamesIt',
    (tester) async {
      final harness = await open(tester);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(harness.fileSaver.saved, hasLength(1));
      expect(
        harness.fileSaver.saved.single.suggestedName,
        'orpheus-data-2026-10-18.json',
      );
      expect(said('Exported to /exports/saved'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlatformThatGivesNoPath_WhenTheyExport_ThenTheDialogSaysOnlyExported',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.next = const SavedFile();

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(said('Exported'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlaylistsStoreThatCannotBeRead_WhenTheyExport_ThenTheDialogSaysSomeDataWasMissed',
    (tester) async {
      await open(tester, failPlaylists: true);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(said('Exported, but some data could not be read'), findsOneWidget);
    },
  );

  testWidgets('GivenASaverThatFails_WhenTheyExport_ThenTheDialogSaysItFailed', (
    tester,
  ) async {
    final harness = await open(tester);
    harness.fileSaver.failure = const FileSystemException('disk full');

    await tapExport(tester);
    await tester.pumpAndSettle();

    expect(said("Couldn't export your data"), findsOneWidget);
  });

  testWidgets(
    'GivenALibraryThatCannotBeRead_WhenTheyExport_ThenTheDialogSaysThereIsNothingToExport',
    (tester) async {
      final harness = await open(tester, failLibrary: true);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(
        said("Your library couldn't be read, so there's nothing to export"),
        findsOneWidget,
      );
      expect(harness.fileSaver.saved, isEmpty);
    },
  );

  testWidgets(
    'GivenTheOwnerCancelsTheDialog_WhenTheyExport_ThenNothingIsSaid',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.next = null;

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(tester.widget<ListTile>(exportTile()).subtitle, isNull);
    },
  );

  testWidgets(
    'GivenAnExportFailed_WhenItIsSaid_ThenNoSnackbarIsShownBehindTheDialog',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.failure = const FileSystemException('disk full');

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'GivenAFailureIsShown_WhenAnotherExportStarts_ThenThePreviousStatusIsClearedWhileItRuns',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.failure = const FileSystemException('disk full');
      await tapExport(tester);
      await tester.pumpAndSettle();
      expect(said("Couldn't export your data"), findsOneWidget);

      // The owner is still choosing where to put the second one.
      final gate = Completer<void>();
      harness.fileSaver
        ..failure = null
        ..gate = gate;
      await tapExport(tester);
      await tester.pump();

      expect(said("Couldn't export your data"), findsNothing);
      expect(tester.widget<ListTile>(exportTile()).enabled, isFalse);

      gate.complete();
      await tester.pumpAndSettle();

      expect(said('Exported to /exports/saved'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenASavedStatusIsShown_WhenAnotherExportIsCancelled_ThenTheStatusIsGone',
    (tester) async {
      final harness = await open(tester);
      await tapExport(tester);
      await tester.pumpAndSettle();
      expect(said('Exported to /exports/saved'), findsOneWidget);

      harness.fileSaver.next = null;
      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(said('Exported to /exports/saved'), findsNothing);
    },
  );

  testWidgets('GivenAProblem_WhenItIsShown_ThenItIsInTheErrorColour', (
    tester,
  ) async {
    await open(tester, failPlaylists: true);

    await tapExport(tester);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(said('Exported, but some data could not be read'))
          .style
          ?.color,
      Theme.of(tester.element(exportTile())).colorScheme.error,
    );
  });

  testWidgets('GivenASuccess_WhenItIsShown_ThenItIsNotInTheErrorColour', (
    tester,
  ) async {
    await open(tester);

    await tapExport(tester);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(said('Exported to /exports/saved')).style?.color,
      Theme.of(tester.element(exportTile())).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('GivenAStatusIsShown_WhenItAppears_ThenItIsALiveRegion', (
    tester,
  ) async {
    await open(tester);

    await tapExport(tester);
    await tester.pumpAndSettle();

    final live = find.ancestor(
      of: said('Exported to /exports/saved'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(live, findsOneWidget);
  });

  testWidgets(
    'GivenAnExportIsRunning_WhenThePreferencesAreShown_ThenTheEntryIsDisabledWithAProgressIndicator',
    (tester) async {
      final harness = await open(tester);
      final gate = Completer<void>();
      harness.catalogs.readGate = gate;

      await tapExport(tester);
      // Not settled: a progress indicator never stops.
      await tester.pump();

      expect(tester.widget<ListTile>(exportTile()).enabled, isFalse);
      expect(
        find.descendant(
          of: exportTile(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(exportTile()).enabled, isTrue);
      expect(
        find.descendant(
          of: exportTile(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'GivenAnExportIsRunning_WhenTheEntryIsTappedAgain_ThenTheFileIsOfferedOnce',
    (tester) async {
      final harness = await open(tester);
      final gate = Completer<void>();
      harness.catalogs.readGate = gate;

      await tapExport(tester);
      await tester.pump();
      await tester.tap(exportTile(), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.fileSaver.saved, hasLength(1));
    },
  );
}

/// A button that opens the preferences, so the dialog has a navigator.
class _OpenPreferences extends StatelessWidget {
  const _OpenPreferences();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => PreferencesDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}
