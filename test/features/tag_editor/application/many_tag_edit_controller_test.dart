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
import 'package:orpheus/features/tag_editor/application/many_tag_edit_controller.dart';
import 'package:orpheus/features/tag_editor/application/tag_edit_controller.dart';
import 'package:orpheus/features/tag_editor/domain/tag_edits.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Read, edit, write, rescan — several tracks.
void main() {
  final first = entry(id: 'one', title: 'One', album: 'Album');
  final second = entry(id: 'two', title: 'Two', album: 'Album');
  final third = entry(id: 'three', title: 'Three', album: 'Album');
  final tracks = [first, second, third];
  final ogg = MusicEntry(
    file: AudioFile(
      path: '/library/song.ogg',
      sizeInBytes: 1,
      modifiedAt: DateTime.utc(2026),
    ),
    metadata: TrackMetadata.empty,
  );

  FileTags tagsOf({Map<AutofillField, Object?> values = const {}}) => FileTags(
    writable: AutofillField.values.toSet(),
    values: {AutofillField.album: 'Album', ...values},
  );

  ({Harness harness, ScriptedScanner scanner}) harnessFor({
    FakeLibraryAccess? access,
  }) {
    final scanner = ScriptedScanner([
      ScanCompleted(
        catalog: MusicCatalog(entries: tracks),
        report: const ScanReport(
          tracks: 3,
          added: 0,
          updated: 3,
          removed: 0,
          reused: 0,
        ),
      ),
    ]);
    final harness = Harness(
      library: tracks,
      access: access,
      // Never the real scanner: a save rescans.
      scanner: scanner,
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    for (final track in tracks) {
      harness.tagWriter.files[track.file.path] = tagsOf();
    }
    // A save starts a rescan and does not wait for it.
    addTearDown(pumpEventQueue);

    return (harness: harness, scanner: scanner);
  }

  ManyTagEditController controllerOf(Harness harness) {
    // Kept alive for the test, as the dialog keeps it alive.
    harness.container.listen(manyTagEditControllerProvider, (_, _) {});

    return harness.read(manyTagEditControllerProvider.notifier);
  }

  ManyTagEditState stateOf(Harness harness) =>
      harness.read(manyTagEditControllerProvider);

  TagForm genre(String text) => TagForm(text: {AutofillField.genre: text});

  test('GivenThreeFlacsAndAnOgg_WhenLoaded_ThenItEditsTheThreeAndSkipsTheOggForItsFormat', () async {
    final (:harness, scanner: _) = harnessFor();

    await controllerOf(harness).load([...tracks, ogg]);

    expect(stateOf(harness).stage, ManyTagEditStage.editing);
    expect(stateOf(harness).skipped.single.reason, SkipReason.format);
    expect(stateOf(harness).skipped.single.entry, ogg);
    expect(stateOf(harness).shared, isNotNull);
    expect(harness.stamps.stamped, [
      for (final track in tracks) track.file.path,
    ]);
  });

  test(
    'GivenAFileWhoseTagsCannotBeRead_WhenLoaded_ThenItIsSkippedAsUnsafe',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.unreadable.add(second.file.path);

      await controllerOf(harness).load(tracks);

      expect(stateOf(harness).stage, ManyTagEditStage.editing);
      expect(stateOf(harness).skipped.single.entry, second);
      expect(stateOf(harness).skipped.single.reason, SkipReason.unsafe);
    },
  );

  test('GivenOnlyOggs_WhenLoaded_ThenItIsUnwritableForItsFormat', () async {
    final (:harness, scanner: _) = harnessFor();

    await controllerOf(harness).load([ogg]);

    expect(stateOf(harness).stage, ManyTagEditStage.unwritable);
    expect(stateOf(harness).unwritable, UnwritableReason.format);
    expect(stateOf(harness).shared, isNull);
  });

  test(
    'GivenAFlacAmongOggsThatIsUnsafe_WhenLoaded_ThenItIsUnwritableAsUnsafe',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.unreadable.add(first.file.path);

      await controllerOf(harness).load([first, ogg]);

      expect(stateOf(harness).stage, ManyTagEditStage.unwritable);
      expect(stateOf(harness).unwritable, UnwritableReason.unsafe);
    },
  );

  test(
    'GivenThreeFlacsAndAnOgg_WhenLoaded_ThenTheFilesAreTheThreeAsRead',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.files[second.file.path] = tagsOf(
        values: const {AutofillField.year: 1997},
      );
      final controller = controllerOf(harness);

      await controller.load([...tracks, ogg]);

      expect(controller.files, hasLength(3));
      expect(controller.files[1].values[AutofillField.year], 1997);
    },
  );

  test(
    'GivenTheFilesAreBeingRead_WhenLoading_ThenItPublishesProgress',
    () async {
      final (:harness, scanner: _) = harnessFor();
      final seen = <(int, int)>[];
      harness.container.listen(manyTagEditControllerProvider, (_, next) {
        if (next.stage == ManyTagEditStage.loading) {
          seen.add((next.done, next.total));
        }
      });

      await harness.read(manyTagEditControllerProvider.notifier).load(tracks);

      expect(seen, containsAllInOrder([(1, 3), (2, 3)]));
      expect(stateOf(harness).total, 3);
    },
  );

  test('GivenAGenreTyped_WhenSaved_ThenEveryFileIsWrittenAgainstItsOwnStampAndOneRescanFollows', () async {
    final (:harness, :scanner) = harnessFor();
    for (final (index, track) in tracks.indexed) {
      harness.stamps.stamps[track.file.path] = AudioFile(
        path: track.file.path,
        sizeInBytes: 2000 + index,
        modifiedAt: DateTime.utc(2026, 10, 13),
      );
    }
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(genre('Rock'));
    await pumpEventQueue();

    expect(harness.tagWriter.writes, hasLength(3));
    expect(harness.tagWriter.writes.map((write) => write.$1), [
      for (final track in tracks) track.file.path,
    ]);
    expect(harness.tagWriter.writes.map((write) => write.$2), [
      for (final _ in tracks) {AutofillField.genre: 'Rock'},
    ]);
    expect(harness.tagWriter.expectations.map((e) => e.sizeInBytes), [
      2000,
      2001,
      2002,
    ]);
    expect(stateOf(harness).stage, ManyTagEditStage.saved);
    expect(stateOf(harness).written, 3);
    expect(stateOf(harness).savedForm?.text[AutofillField.genre], 'Rock');
    expect(scanner.requests, hasLength(1));
  });

  test('GivenAGenreTypedThatTwoFilesAlreadyHold_WhenSaved_ThenOnlyTheFilesThatDifferAreWritten', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.files[first.file.path] = tagsOf(
      values: {AutofillField.genre: 'Rock'},
    );
    harness.tagWriter.files[second.file.path] = tagsOf(
      values: {AutofillField.genre: 'Rock'},
    );
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(genre('Rock'));
    await pumpEventQueue();

    expect(harness.tagWriter.writes.single.$1, third.file.path);
    expect(stateOf(harness).written, 1);
    expect(stateOf(harness).stage, ManyTagEditStage.saved);
  });

  test(
    'GivenAnUntouchedMixedYear_WhenGenreIsSaved_ThenNoWriteHoldsAYear',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.files[first.file.path] = tagsOf(
        values: {AutofillField.year: 1997},
      );
      harness.tagWriter.files[second.file.path] = tagsOf(
        values: {AutofillField.year: 2001},
      );
      final controller = controllerOf(harness);
      await controller.load(tracks);

      await controller.save(
        const TagForm(
          text: {AutofillField.genre: 'Rock', AutofillField.year: ''},
        ),
      );
      await pumpEventQueue();

      expect(harness.tagWriter.writes, hasLength(3));
      expect(
        harness.tagWriter.writes.every(
          (write) => !write.$2.containsKey(AutofillField.year),
        ),
        isTrue,
      );
    },
  );

  test(
    'GivenOneFileInUse_WhenSaved_ThenTheOthersAreWrittenAndItIsListed',
    () async {
      final (:harness, :scanner) = harnessFor();
      harness.tagWriter.refusals[second.file.path] = WriteOutcome.inUse;
      final controller = controllerOf(harness);
      await controller.load(tracks);

      await controller.save(genre('Rock'));
      await pumpEventQueue();

      expect(stateOf(harness).stage, ManyTagEditStage.results);
      expect(stateOf(harness).written, 2);
      expect(stateOf(harness).failed.single.entry, second);
      expect(stateOf(harness).failed.single.outcome, WriteOutcome.inUse);
      expect(stateOf(harness).failed.single.retryable, isTrue);
      expect(scanner.requests, hasLength(1));
    },
  );

  test(
    'GivenAFileInUse_WhenTryAgainAfterItIsFree_ThenOnlyItIsWritten',
    () async {
      final (:harness, scanner: _) = harnessFor();
      harness.tagWriter.refusals[second.file.path] = WriteOutcome.inUse;
      final controller = controllerOf(harness);
      await controller.load(tracks);
      await controller.save(genre('Rock'));

      harness.tagWriter.refusals.remove(second.file.path);
      await controller.retry();
      await pumpEventQueue();

      final paths = harness.tagWriter.writes.map((write) => write.$1).toList();
      expect(paths, hasLength(3));
      expect(paths.toSet(), hasLength(3));
      expect(paths.last, second.file.path);
      expect(stateOf(harness).stage, ManyTagEditStage.saved);
      expect(stateOf(harness).written, 3);
      expect(stateOf(harness).failed, isEmpty);
    },
  );

  test('GivenAFileChangedSinceRead_WhenTryAgain_ThenItIsReadAgainAndNotWrittenWhereItHoldsTheEditAlready', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.refusals[second.file.path] =
        WriteOutcome.changedSinceRead;
    final controller = controllerOf(harness);
    await controller.load(tracks);
    await controller.save(genre('Rock'));
    expect(
      stateOf(harness).failed.single.outcome,
      WriteOutcome.changedSinceRead,
    );
    expect(harness.tagWriter.writes, hasLength(2));

    // Another program retagged it meanwhile, with the genre the owner typed.
    harness.tagWriter.refusals.remove(second.file.path);
    harness.tagWriter.files[second.file.path] = tagsOf(
      values: {AutofillField.genre: 'Rock'},
    );
    await controller.retry();
    await pumpEventQueue();

    // Measured against what it holds now, there is nothing to write.
    expect(harness.tagWriter.writes, hasLength(2));
    expect(stateOf(harness).failed, isEmpty);
    expect(stateOf(harness).stage, ManyTagEditStage.saved);
  });

  test('GivenAChangedFileNowUnsafe_WhenTryAgain_ThenItIsListedAsUnsupportedAndNotRetryable', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.refusals[second.file.path] =
        WriteOutcome.changedSinceRead;
    final controller = controllerOf(harness);
    await controller.load(tracks);
    await controller.save(genre('Rock'));

    // Rewritten meanwhile into a tag the writer will not change safely.
    harness.tagWriter.refusals.remove(second.file.path);
    harness.tagWriter.files[second.file.path] = FileTags.unwritable;
    await controller.retry();

    final failure = stateOf(harness).failed.single;
    expect(failure.entry, second);
    expect(failure.outcome, WriteOutcome.unsupported);
    expect(failure.retryable, isFalse);
    expect(stateOf(harness).stage, ManyTagEditStage.results);

    await controller.retry();
    expect(harness.tagWriter.writes, hasLength(2));
  });

  test('GivenAFileChangedSinceReadThatCannotBeReadAgain_WhenTryAgain_ThenItStaysFailed', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.refusals[second.file.path] =
        WriteOutcome.changedSinceRead;
    final controller = controllerOf(harness);
    await controller.load(tracks);
    await controller.save(genre('Rock'));

    harness.tagWriter.unreadable.add(second.file.path);
    await controller.retry();

    expect(stateOf(harness).stage, ManyTagEditStage.results);
    expect(stateOf(harness).failed.single.entry, second);
    expect(stateOf(harness).failed.single.outcome, WriteOutcome.failed);
    expect(harness.tagWriter.writes, hasLength(2));
  });

  test('GivenAChangedFileWhoseReadAgainThrew_WhenTriedAgainOnceMore_ThenItIsReadAgainAndWrittenAgainstTheNewStamp', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.refusals[second.file.path] =
        WriteOutcome.changedSinceRead;
    final controller = controllerOf(harness);
    await controller.load(tracks);
    await controller.save(genre('Rock'));
    harness.tagWriter.refusals.remove(second.file.path);
    harness.tagWriter.unreadable.add(second.file.path);
    await controller.retry();
    expect(stateOf(harness).failed.single.outcome, WriteOutcome.failed);

    // Readable again, and changed once more since the stamp it was refused
    // against.
    harness.tagWriter.unreadable.remove(second.file.path);
    harness.stamps.stamps[second.file.path] = AudioFile(
      path: second.file.path,
      sizeInBytes: 4096,
      modifiedAt: DateTime.utc(2026, 10, 14),
    );
    await controller.retry();
    await pumpEventQueue();

    expect(harness.tagWriter.writes.last.$1, second.file.path);
    expect(harness.tagWriter.writes.last.$2, {AutofillField.genre: 'Rock'});
    expect(harness.tagWriter.expectations.last.sizeInBytes, 4096);
    expect(stateOf(harness).stage, ManyTagEditStage.saved);
  });

  test('GivenADeniedFile_WhenSaved_ThenItIsListedAndNotRetryable', () async {
    final (:harness, scanner: _) = harnessFor();
    harness.tagWriter.refusals[third.file.path] = WriteOutcome.denied;
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(genre('Rock'));
    await controller.retry();

    expect(stateOf(harness).stage, ManyTagEditStage.results);
    expect(stateOf(harness).failed.single.outcome, WriteOutcome.denied);
    expect(stateOf(harness).failed.single.retryable, isFalse);
    expect(harness.tagWriter.writes, hasLength(2));
  });

  test('GivenAFileWithNoTrackNumber_WhenATrackTotalIsSaved_ThenItKeepsItsTotalAndIsNoted', () async {
    final (:harness, scanner: _) = harnessFor();
    for (final track in [first, second]) {
      harness.tagWriter.files[track.file.path] = tagsOf(
        values: {AutofillField.trackNumber: 1},
      );
    }
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(
      const TagForm(
        text: {AutofillField.trackTotal: '12', AutofillField.genre: 'Rock'},
      ),
    );
    await pumpEventQueue();

    expect(stateOf(harness).totalsLeft.single.entry, third);
    expect(stateOf(harness).totalsLeft.single.totals, {
      AutofillField.trackTotal,
    });
    expect(stateOf(harness).failed, isEmpty);
    expect(stateOf(harness).stage, ManyTagEditStage.results);
    expect(stateOf(harness).written, 3);
    expect(harness.tagWriter.writes.last.$1, third.file.path);
    expect(harness.tagWriter.writes.last.$2, {AutofillField.genre: 'Rock'});
  });

  test('GivenAccessRefused_WhenSaved_ThenNothingIsWrittenAndItIsEditingWithTheRefusal', () async {
    final access = FakeLibraryAccess()
      ..writeDecision = LibraryAccessDecision.deniedPermanently;
    final (:harness, :scanner) = harnessFor(access: access);
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(genre('Rock'));
    await pumpEventQueue();

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, ManyTagEditStage.editing);
    expect(stateOf(harness).refusal, LibraryAccessDecision.deniedPermanently);
    expect(scanner.requests, isEmpty);
  });

  test('GivenWriteAccessThatThrows_WhenSaved_ThenNothingIsWrittenAndItIsEditingAgain', () async {
    final access = FakeLibraryAccess()..writeError = StateError('platform');
    final (:harness, :scanner) = harnessFor(access: access);
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(genre('Rock'));
    await pumpEventQueue();

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, ManyTagEditStage.editing);
    expect(scanner.requests, isEmpty);

    // Not stuck: a later save goes through.
    access.writeError = null;
    await controller.save(genre('Rock'));
    expect(harness.tagWriter.writes, hasLength(3));
  });

  test('GivenWriteAccessThatThrows_WhenTryAgain_ThenNothingIsWrittenAndTheResultsStay', () async {
    final access = FakeLibraryAccess();
    final (:harness, scanner: _) = harnessFor(access: access);
    harness.tagWriter.refusals[second.file.path] = WriteOutcome.inUse;
    final controller = controllerOf(harness);
    await controller.load(tracks);
    await controller.save(genre('Rock'));
    harness.tagWriter.refusals.remove(second.file.path);

    access.writeError = StateError('platform');
    await controller.retry();

    expect(harness.tagWriter.writes, hasLength(2));
    expect(stateOf(harness).stage, ManyTagEditStage.results);
    expect(stateOf(harness).failed.single.outcome, WriteOutcome.inUse);
  });

  test('GivenNoChanges_WhenSaved_ThenNothingIsWritten', () async {
    final (:harness, :scanner) = harnessFor();
    final controller = controllerOf(harness);
    await controller.load(tracks);

    await controller.save(const TagForm());
    await pumpEventQueue();

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, ManyTagEditStage.saved);
    expect(stateOf(harness).written, 0);
    expect(scanner.requests, isEmpty);
  });

  test('GivenASaveInFlight_WhenSavedAgain_ThenTheSecondIsIgnored', () async {
    final (:harness, scanner: _) = harnessFor();
    final controller = controllerOf(harness);
    await controller.load(tracks);
    final gate = Completer<void>();
    harness.tagWriter.hold = gate.future;

    final firstSave = controller.save(genre('Rock'));
    final secondSave = controller.save(genre('Rock'));
    gate.complete();
    await Future.wait([firstSave, secondSave]);

    expect(harness.tagWriter.writes, hasLength(3));
  });

  test('GivenTheControllerDisposedMidSave_WhenTheWritesFinish_ThenEveryFileIsWrittenAndTheLibraryRescanned', () async {
    final (:harness, :scanner) = harnessFor();
    final subscription = harness.container.listen(
      manyTagEditControllerProvider,
      (_, _) {},
    );
    final controller = harness.read(manyTagEditControllerProvider.notifier);
    await controller.load(tracks);
    final gate = Completer<void>();
    harness.tagWriter.hold = gate.future;

    final saving = controller.save(genre('Rock'));
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    gate.complete();
    await saving;
    await pumpEventQueue();

    expect(harness.tagWriter.writes, hasLength(3));
    expect(scanner.requests, hasLength(1));
  });
}
