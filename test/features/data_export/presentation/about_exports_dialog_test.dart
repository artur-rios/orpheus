import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/presentation/about_exports_dialog.dart';

import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// *About these exports*: the comparison of the JSON export and the ZIP backup
/// the design spells out.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpHarness(Harness(), const _OpenAbout());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The table as the words in its cells, row by row.
  List<List<String>> cells(WidgetTester tester) {
    final table = tester.widget<Table>(find.byType(Table));

    return [
      for (final row in table.children)
        [
          for (final cell in row.children)
            tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byWidget(cell),
                    matching: find.byType(Text),
                  ),
                )
                .map((text) => text.data!)
                .join(),
        ],
    ];
  }

  testWidgets('GivenTheAboutEntry_WhenItOpens_ThenItIsTitledAndOffersToClose', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('About these exports'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutExportsDialog), findsNothing);
  });

  testWidgets(
    'GivenTheAboutEntry_WhenItOpens_ThenTheTableSaysWhatEachExportHolds',
    (tester) async {
      await open(tester);

      expect(cells(tester), [
        ['', 'Export my data (JSON)', 'Back up Orpheus (ZIP)'],
        [
          'For',
          'Looking at your data in other tools, importing elsewhere',
          'Restoring Orpheus on this or another device',
        ],
        ['Songs, artists, albums (as a list)', '✓', '✓'],
        ['Playlists', '✓', '✓'],
        ['Auto playlists (as they are now)', '✓', '✓'],
        ['Play history and statistics', '✓', '✓'],
        ['Playlist cover pictures', '—', '✓'],
        ['Preferences (incl. music folders)', '—', '✓'],
        ['Your music files', '—', '—'],
      ]);
    },
  );

  testWidgets(
    'GivenTheMarks_WhenTheyAreRead_ThenTheyAreSpokenAsIncludedOrNotIncluded',
    (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);

      expect(find.bySemanticsLabel('Included'), findsNWidgets(10));
      expect(find.bySemanticsLabel('Not included'), findsNWidgets(4));

      handle.dispose();
    },
  );
}

/// A button that opens the dialog, so it has a navigator.
class _OpenAbout extends StatelessWidget {
  const _OpenAbout();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => AboutExportsDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}
