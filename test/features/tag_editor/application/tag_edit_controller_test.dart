import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';
import 'package:orpheus/features/tag_editor/application/tag_edit_controller.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Read, edit, write, rescan — one track.
void main() {
  final track = entry(id: 'airbag', title: 'Airbag', artist: 'Radiohed');
  final path = track.file.path;

  ({Harness harness, ScriptedScanner scanner}) harnessFor({
    FakeLibraryAccess? access,
  }) {
    final scanner = ScriptedScanner([
      ScanCompleted(
        catalog: MusicCatalog(entries: [track]),
        report: const ScanReport(
          tracks: 1,
          added: 0,
          updated: 1,
          removed: 0,
          reused: 0,
        ),
      ),
    ]);
    final harness = Harness(
      library: [track],
      access: access,
      // Never the real scanner: a save rescans.
      scanner: scanner,
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    harness.tagWriter.files[path] = FileTags(
      writable: AutofillField.values.toSet(),
      values: const {
        AutofillField.title: 'Airbag',
        AutofillField.artist: 'Radiohed',
      },
    );
    // A save starts a rescan and does not wait for it.
    addTearDown(pumpEventQueue);

    return (harness: harness, scanner: scanner);
  }

  TagEditController controllerOf(Harness harness) {
    // Kept alive for the test, as the dialog keeps it alive.
    harness.container.listen(tagEditControllerProvider, (_, _) {});

    return harness.read(tagEditControllerProvider.notifier);
  }

  TagEditState stateOf(Harness harness) =>
      harness.read(tagEditControllerProvider);

  test('GivenAFlac_WhenLoaded_ThenItIsEditingWhatTheFileSays', () async {
    final (:harness, scanner: _) = harnessFor();

    await controllerOf(harness).load(track);

    expect(stateOf(harness).stage, TagEditStage.editing);
    expect(stateOf(harness).tags.values[AutofillField.artist], 'Radiohed');
    expect(harness.stamps.stamped, [path]);
  });

  test('GivenAnOggFile_WhenLoaded_ThenItCannotBeEditedForItsFormat', () async {
    final (:harness, scanner: _) = harnessFor();
    final ogg = MusicEntry(
      file: AudioFile(
        path: '/library/song.ogg',
        sizeInBytes: 1,
        modifiedAt: DateTime.utc(2026),
      ),
      metadata: TrackMetadata.empty,
    );

    await controllerOf(harness).load(ogg);

    expect(stateOf(harness).stage, TagEditStage.unwritable);
    expect(stateOf(harness).unwritable, UnwritableReason.format);
    expect(harness.stamps.stamped, isEmpty);
  });

  test(
    'GivenAFlacWithNothingWritable_WhenLoaded_ThenItCannotBeEditedSafely',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.files.remove(path);

      await controllerOf(harness).load(track);

      expect(stateOf(harness).stage, TagEditStage.unwritable);
      expect(stateOf(harness).unwritable, UnwritableReason.unsafe);
    },
  );

  test(
    'GivenTagsThatCannotBeRead_WhenLoaded_ThenItCannotBeEditedSafely',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.unreadable.add(path);

      await controllerOf(harness).load(track);

      expect(stateOf(harness).stage, TagEditStage.unwritable);
      expect(stateOf(harness).unwritable, UnwritableReason.unsafe);
    },
  );

  test('GivenAnEdit_WhenSaved_ThenItIsWrittenAgainstTheStampAndTheLibraryRescanned', () async {
    final (:harness, :scanner) = harnessFor();
    final stamp = AudioFile(
      path: path,
      sizeInBytes: 2048,
      modifiedAt: DateTime.utc(2026, 10, 13),
    );
    harness.stamps.stamps[path] = stamp;
    final controller = controllerOf(harness);
    await controller.load(track);

    await controller.save({AutofillField.artist: 'Radiohead'});
    await pumpEventQueue();

    expect(harness.tagWriter.writes.single.$1, path);
    expect(harness.tagWriter.writes.single.$2, {
      AutofillField.artist: 'Radiohead',
    });
    expect(harness.tagWriter.expectations.single.sizeInBytes, 2048);
    expect(stateOf(harness).stage, TagEditStage.saved);
    expect(scanner.requests, hasLength(1));
  });

  test('GivenNoEdits_WhenSaved_ThenNothingIsWritten', () async {
    final (:harness, :scanner) = harnessFor();
    final controller = controllerOf(harness);
    await controller.load(track);

    await controller.save(const {});

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, TagEditStage.editing);
    expect(scanner.requests, isEmpty);
  });

  test(
    'GivenTheFileIsInUse_WhenSaved_ThenItIsEditingWithTheReasonAndNoRescan',
    () async {
      final (:harness, :scanner) = harnessFor();
      harness.tagWriter.refusals[path] = WriteOutcome.inUse;
      final controller = controllerOf(harness);
      await controller.load(track);

      await controller.save({AutofillField.artist: 'Radiohead'});
      await pumpEventQueue();

      expect(stateOf(harness).stage, TagEditStage.editing);
      expect(stateOf(harness).outcome, WriteOutcome.inUse);
      expect(scanner.requests, isEmpty);
    },
  );

  test('GivenWriteAccessIsRefused_WhenSaved_ThenNothingIsWritten', () async {
    final access = FakeLibraryAccess()
      ..writeDecision = LibraryAccessDecision.deniedPermanently;
    final (:harness, scanner: _) = harnessFor(access: access);
    final controller = controllerOf(harness);
    await controller.load(track);

    await controller.save({AutofillField.artist: 'Radiohead'});

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, TagEditStage.editing);
    expect(stateOf(harness).refusal, LibraryAccessDecision.deniedPermanently);
  });

  test('GivenASaveInFlight_WhenSavedAgain_ThenTheFileIsWrittenOnce', () async {
    final (:harness, scanner: _) = harnessFor();
    final controller = controllerOf(harness);
    await controller.load(track);
    final gate = Completer<void>();
    harness.tagWriter.hold = gate.future;

    final first = controller.save({AutofillField.artist: 'Radiohead'});
    final second = controller.save({AutofillField.artist: 'Radiohead'});
    gate.complete();
    await Future.wait([first, second]);

    expect(harness.tagWriter.writes, hasLength(1));
  });

  test(
    'GivenTheFileChangedSinceRead_WhenReloaded_ThenTheNewTagsAndStampAreUsed',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.refusals[path] = WriteOutcome.changedSinceRead;
      final controller = controllerOf(harness);
      await controller.load(track);
      await controller.save({AutofillField.artist: 'Radiohead'});
      expect(stateOf(harness).outcome, WriteOutcome.changedSinceRead);

      // Another program retagged it meanwhile.
      harness.tagWriter.refusals.remove(path);
      harness.tagWriter.files[path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: const {AutofillField.title: 'Airbag (Live)'},
      );
      final newer = AudioFile(
        path: path,
        sizeInBytes: 4096,
        modifiedAt: DateTime.utc(2026, 10, 14),
      );
      harness.stamps.stamps[path] = newer;
      await controller.reload();

      expect(stateOf(harness).stage, TagEditStage.editing);
      expect(stateOf(harness).outcome, isNull);
      expect(
        stateOf(harness).tags.values[AutofillField.title],
        'Airbag (Live)',
      );

      await controller.save({AutofillField.artist: 'Radiohead'});
      expect(harness.tagWriter.expectations.last.sizeInBytes, 4096);
    },
  );

  test('GivenTheDialogClosesWhileWriting_WhenTheWriteFinishes_ThenTheLibraryIsStillRescanned', () async {
    final (:harness, :scanner) = harnessFor();
    final subscription = harness.container.listen(
      tagEditControllerProvider,
      (_, _) {},
    );
    final controller = harness.read(tagEditControllerProvider.notifier);
    await controller.load(track);
    final gate = Completer<void>();
    harness.tagWriter.hold = gate.future;

    final saving = controller.save({AutofillField.artist: 'Radiohead'});
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    gate.complete();
    await saving;
    await pumpEventQueue();

    expect(harness.tagWriter.writes, hasLength(1));
    expect(scanner.requests, hasLength(1));
  });
}
