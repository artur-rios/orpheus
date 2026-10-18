import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_launcher.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Which form an edit over some tracks opens.
void main() {
  final track = entry(id: 'airbag', title: 'Airbag', album: 'OK Computer');

  Future<void> start(WidgetTester tester, List<MusicEntry> entries) async {
    final harness = Harness(
      library: [track],
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    harness.tagWriter.files[track.file.path] = FileTags(
      writable: AutofillField.values.toSet(),
      values: const {AutofillField.title: 'Airbag'},
    );
    await tester.pumpHarness(
      harness,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                startManyTagEdit(context, entries, label: 'OK Computer'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('GivenOneEntry_WhenStarted_ThenTheOneTrackFormOpens', (
    tester,
  ) async {
    await start(tester, [track]);

    expect(find.byType(EditTagsDialog), findsOneWidget);
    expect(find.byType(EditManyTagsDialog), findsNothing);
  });

  testWidgets('GivenNoEntries_WhenStarted_ThenNothingOpens', (tester) async {
    await start(tester, const []);

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('what the launcher answers', () {
    final first = entry(id: 'first', title: 'First', album: 'OK Computer');
    final second = entry(id: 'second', title: 'Second', album: 'OK Computer');
    final both = [first, second];

    /// The form over two songs, with what the launcher answered kept in
    /// [answers].
    Future<void> openForm(WidgetTester tester, List<bool> answers) async {
      final harness = Harness(
        library: both,
        // Never the real scanner: a save rescans.
        scanner: ScriptedScanner([
          ScanCompleted(
            catalog: MusicCatalog(entries: both),
            report: const ScanReport(
              tracks: 2,
              added: 0,
              updated: 2,
              removed: 0,
              reused: 0,
            ),
          ),
        ]),
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );
      for (final track in both) {
        harness.tagWriter.files[track.file.path] = FileTags(
          writable: AutofillField.values.toSet(),
          values: const {
            AutofillField.artist: 'Radiohead',
            AutofillField.album: 'OK Computer',
          },
        );
      }
      await tester.pumpHarness(
        harness,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await startManyTagEdit(context, both, label: 'OK Computer'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('GivenAManyTrackSave_WhenItWrites_ThenTheLauncherAnswersTrue', (
      tester,
    ) async {
      final answers = <bool>[];
      await openForm(tester, answers);

      await tester.enterText(
        find.byKey(const ValueKey(AutofillField.genre)),
        'Alternative',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(answers, [true]);
    });

    testWidgets('GivenAManyTrackForm_WhenCancelled_ThenTheLauncherAnswersFalse', (
      tester,
    ) async {
      final answers = <bool>[];
      await openForm(tester, answers);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });
  });
}
