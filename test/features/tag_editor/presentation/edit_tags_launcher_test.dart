import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_launcher.dart';

import '../../../support/entries.dart';
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
}
