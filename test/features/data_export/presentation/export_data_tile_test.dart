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
    'GivenTheOwnerChoosesAPlace_WhenTheyExport_ThenTheFileIsSavedAndTheSnackbarNamesIt',
    (tester) async {
      final harness = await open(tester);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(harness.fileSaver.saved, hasLength(1));
      expect(
        harness.fileSaver.saved.single.suggestedName,
        'orpheus-data-2026-10-18.json',
      );
      expect(find.text('Exported to /exports/saved'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlatformThatGivesNoPath_WhenTheyExport_ThenTheSnackbarSaysOnlyExported',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.next = const SavedFile();

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(find.text('Exported'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlaylistsStoreThatCannotBeRead_WhenTheyExport_ThenTheSnackbarSaysSomeDataWasMissed',
    (tester) async {
      await open(tester, failPlaylists: true);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Exported, but some data could not be read'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenASaverThatFails_WhenTheyExport_ThenTheSnackbarSaysItFailed',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.failure = const FileSystemException('disk full');

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't export your data"), findsOneWidget);
    },
  );

  testWidgets(
    'GivenALibraryThatCannotBeRead_WhenTheyExport_ThenTheSnackbarSaysThereIsNothingToExport',
    (tester) async {
      final harness = await open(tester, failLibrary: true);

      await tapExport(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Your library couldn't be read, so there's nothing to export",
        ),
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
    },
  );

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
