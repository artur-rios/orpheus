# Edit the tags of several tracks at once — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One form, opened from an album's or an artist's menu, that edits the shared tags of all its tracks and
writes only what the owner changed, file by file, reporting each failure.

**Architecture:** A pure domain (`shared_tags.dart`) works out what the files share and each file's edits, reusing
`tag_edits.dart`; an auto-disposed `ManyTagEditController` reads, writes sequentially through the autofill's
`TagWriter` and rescans once; `EditManyTagsDialog` is the form, and a new `MusicGroupMenu` on album/artist rows opens
it over the whole library's tracks of that album or artist.

**Tech Stack:** Flutter 3.47.2, Riverpod `Notifier`, `flutter_test`, ARB localisations (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-18-edit-many-tags-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; outward things only from `core/di/providers.dart`.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`. Use `test/support` harness and fakes
  (`Harness`, `FakeTagWriter`, `FakeFileStamps`, `FakeCoverPicker`, `ScriptedScanner`, `entry()`).
- Every new string in **both** `app_en.arb` and `app_pt.arb`, with an `@key` description, same placeholders
  (`test/core/l10n/catalog_parity_test.dart`). Regenerate with `flutter gen-l10n`.
- No colour literals outside `lib/core/theme/`.
- Only MP3 and FLAC are written (`canWriteTagsTo`). With more than one track, title and track number are never offered.
- The one-track editor (UC-35) keeps its behaviour; an album/artist of one track opens it.
- Tracks are gathered from the **whole library**, never from `group.entries` alone.
- Verification: `flutter analyze` clean, `dart format --set-exit-if-changed lib test`, `flutter test` green.
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A mixed field the owner never touched** must be written to no file — e.g. an artist whose albums carry different
   years, saved after changing only the genre, keeps every year. (Task 1 `…MixedYearLeftBlank…`, Task 2 write
   assertions.)
2. **A file that already holds the typed value** is not rewritten — saving `Rock` as genre over an album where 10 of 12
   say `Rock` writes 2 files. (Task 1, Task 2 `…OnlyTheFilesThatDiffer…`.)
3. **The dialog closed or the app navigated mid-save** — the remaining files are still written and one rescan
   follows. (Task 2 `…DisposedMidSave…`.)
4. **An artist whose untagged group is opened** (album artist `null`) gathers the untagged group, not nothing and not
   the whole library. (Task 4 `…UntaggedArtist…`.)
5. **Try again after a partial save** writes only the failed files, never the written ones a second time. (Task 2
   `…TryAgain…`.)

---

### Task 1: What several files share, and each file's edits

**Files:**
- Create: `lib/features/tag_editor/domain/shared_tags.dart`
- Test: `test/features/tag_editor/domain/shared_tags_test.dart`

**Interfaces:**
- Consumes: `FileTags`, `AutofillField` (autofill domain); `TagForm`, `CoverChoice` (`KeepCover`, `RemoveCover`,
  `ReplaceCover`), `numberProblem`, `NumberProblem`, `numberFields` from `tag_edits.dart`.
- Produces:
  ```dart
  const List<AutofillField> sharedTextFields; // artist, albumArtist, album, trackTotal, discNumber, discTotal, year, genre
  sealed class Shared<T> { const Shared(); }
  final class Same<T> extends Shared<T> { const Same(this.value); final T? value; }
  final class Mixed<T> extends Shared<T> { const Mixed(); }
  class SharedTags {
    factory SharedTags.of(List<FileTags> files);   // files non-empty
    final Map<AutofillField, Shared<Object>> values; // keyed by sharedTextFields
    final Shared<Uint8List> cover;
    final Set<AutofillField> writable;               // union of files' writable
    bool get anyCover;                               // some file has a cover
  }
  String sharedText(SharedTags shared, AutofillField field); // Same → value.toString() or ''; Mixed → ''
  bool isMixed(SharedTags shared, AutofillField field);
  Map<AutofillField, NumberProblem> sharedNumberProblems(SharedTags shared, TagForm form);
  bool hasSharedChanges(SharedTags shared, TagForm form); // any changed text field, or a cover choice that is not keep
  class FileEdits {
    const FileEdits({this.values = const {}, this.leftForMissingNumber = const {}});
    final Map<AutofillField, Object?> values;
    final Set<AutofillField> leftForMissingNumber;   // trackTotal and/or discTotal
  }
  FileEdits editsFor(FileTags file, SharedTags shared, TagForm form);
  ```

Rules (spec §4.1): a field is changed when `form.text[field]?.trim()` differs from `sharedText(...).trim()`; a changed
field's value is `null` for empty, an `int` for number fields (only when `numberProblem` is null), else the trimmed
string; it goes into a file's edits only if `file.writable` holds it and `file.values[field]` differs. Cover per file:
`RemoveCover` → `null` where `file.cover != null`; `ReplaceCover(b)` → `b` where the file's cover is not byte-equal.
Pairs (`trackNumber`/`trackTotal`, `discNumber`/`discTotal`): after the edits, if the file would hold a total and no
number, drop that pair's keys from `values` and add the total to `leftForMissingNumber`.

- [ ] **Step 1: Write the failing tests** — each builds `FileTags` with `writable: AutofillField.values.toSet()` unless
  it says otherwise:
  - `GivenTwoFilesWithTheSameAlbum_WhenShared_ThenTheAlbumIsTheSame` → `values[album]` is `Same('OK Computer')`,
    `sharedText` `'OK Computer'`.
  - `GivenTwoFilesWithDifferentYears_WhenShared_ThenTheYearIsMixedAndStartsBlank` → `Mixed`, `sharedText` `''`.
  - `GivenOneFileWithAGenreAndOneWithout_WhenShared_ThenTheGenreIsMixed`.
  - `GivenNoFileWithAGenre_WhenShared_ThenTheGenreIsSameNone` → `Same(null)`.
  - `GivenOneFileHoldingRockPop_AndOneRock_WhenShared_ThenTheGenreIsMixed`.
  - `GivenTheSameCoverBytes_WhenShared_ThenTheCoverIsTheSame`; `…DifferentCovers…ThenMixed`; `…NoCovers…ThenSameNone`.
  - `GivenAFlacAndAFileThatCannotHoldYear_WhenShared_ThenYearIsWritableFromTheUnion`.
  - `GivenAMixedYearLeftBlank_WhenEditsAreWorkedOut_ThenNoFileGetsAYear` → `editsFor(...).values` has no `year`.
  - `GivenAMixedGenreTypedAsJazz_WhenEditsAreWorkedOut_ThenEveryFileGetsJazz`.
  - `GivenAFileThatAlreadyHoldsTheTypedGenre_WhenEditsAreWorkedOut_ThenItHasNoEdit` → `values` empty.
  - `GivenASameAlbumCleared_WhenEditsAreWorkedOut_ThenItIsRemoved` → `{album: null}`.
  - `GivenATrackTotalOf03OverAFileHolding3_WhenEditsAreWorkedOut_ThenNoChange`.
  - `GivenAFileThatCannotHoldGenre_WhenGenreIsTyped_ThenItsEditsLeaveGenreOut`.
  - `GivenRemoveCover_WhenEditsAreWorkedOut_ThenOnlyFilesWithACoverLoseIt` (one with, one without → `{cover: null}`
    and `{}`).
  - `GivenReplaceCover_WhenAFileAlreadyHoldsThoseBytes_ThenItHasNoCoverEdit`.
  - `GivenATrackTotalForAFileWithNoTrackNumber_WhenEditsAreWorkedOut_ThenTheTotalIsLeftAndNoted` → `values` has no
    `trackTotal` but keeps a typed `genre`; `leftForMissingNumber == {trackTotal}`.
  - `GivenTheDiscNumberClearedWhileAFileHoldsADiscTotal_WhenEditsAreWorkedOut_ThenThePairIsLeftAndNoted` →
    neither `discNumber` nor `discTotal` in `values`; `{discTotal}` noted.
  - `GivenAYearOf10000_WhenChecked_ThenItIsAProblem` → `sharedNumberProblems` `{year: yearOutOfRange}`.
  - `GivenAMixedNumberLeftBlank_WhenChecked_ThenItIsNoProblem`.
  - `GivenNothingTyped_WhenAskedForChanges_ThenThereAreNone`; `GivenRemoveCover_…ThenThereAreChanges`.

- [ ] **Step 2: Run** `flutter test test/features/tag_editor/domain/shared_tags_test.dart` — FAIL (file missing).
- [ ] **Step 3: Implement** `shared_tags.dart` with the interfaces above. Byte comparison: reuse a private
  `_sameBytes` (copy the 8-line helper; `tag_edits.dart`'s is private). Doc comments in the codebase's style.
- [ ] **Step 4: Run** the test — PASS. `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: work out the tags several files share`.

---

### Task 2: The controller over several tracks

**Files:**
- Create: `lib/features/tag_editor/application/many_tag_edit_controller.dart`
- Modify: `lib/core/di/providers.dart` (add `manyTagEditControllerProvider` beside `tagEditControllerProvider`)
- Test: `test/features/tag_editor/application/many_tag_edit_controller_test.dart`

**Interfaces:**
- Consumes: Task 1; `tagWriterProvider`, `fileStampsProvider`, `libraryAccessControllerProvider`,
  `scanControllerProvider` (`rescanSoon()`), `canWriteTagsTo`, `WriteOutcome`, `LibraryAccessDecision`.
- Produces:
  ```dart
  enum ManyTagEditStage { loading, unwritable, editing, saving, results, saved }
  enum SkipReason { format, unsafe }
  class SkippedTrack { final MusicEntry entry; final SkipReason reason; }
  class FailedTrack { final MusicEntry entry; final WriteOutcome outcome; bool get retryable; } // inUse, failed, changedSinceRead
  class TotalLeft { final MusicEntry entry; final Set<AutofillField> totals; }
  class ManyTagEditState {
    final ManyTagEditStage stage;
    final int done, total;                 // progress of the current read or save
    final SharedTags? shared;              // null until read
    final List<SkippedTrack> skipped;
    final UnwritableReason? unwritable;    // from tag_edit_controller.dart: unsafe if any skipped was unsafe
    final int written;                     // files written across every save so far
    final List<FailedTrack> failed;
    final List<TotalLeft> totalsLeft;
    final LibraryAccessDecision? refusal;
    final TagForm? savedForm;              // the form as saved; set from the first save on
  }
  final manyTagEditControllerProvider =
      NotifierProvider<ManyTagEditController, ManyTagEditState>(ManyTagEditController.new, isAutoDispose: true);
  class ManyTagEditController extends Notifier<ManyTagEditState> {
    Future<void> load(List<MusicEntry> entries);
    Future<void> save(TagForm form);   // editing → saving → saved | results; refused → editing + refusal
    Future<void> retry();              // results → saving over `failed` with savedForm
  }
  ```

Behaviour (spec §4.2): `load` publishes `done/total` per file; files skipped as in the spec; none left →
`unwritable`. `save`/`retry` are guarded by a `_saving` flag; `ref.read` access, writer, stamps and scan **before**
the first await; per file `editsFor` → empty values counts as done; else `write(path, values, expected: stamp)`;
`ref.mounted` is checked only before touching `state`, never to stop the loop; after the loop, one `rescanSoon()` if
any file was written this pass. The pass ends in `results` when any file failed **or** any total was left
(`totalsLeft` non-empty), so the owner sees the note; otherwise `saved`. `retry` re-stamps and re-inspects each `changedSinceRead` file first (a throw keeps it
failed as `failed`) and only retries `retryable` ones; non-retryable failures stay listed.

- [ ] **Step 1: Write the failing tests** (Harness as in `tag_edit_controller_test.dart`; three FLAC entries of one
  album plus one `.ogg`; `harness.tagWriter.files[path]` per file; keep the controller alive with
  `container.listen`):
  - `GivenThreeFlacsAndAnOgg_WhenLoaded_ThenItEditsTheThreeAndSkipsTheOggForItsFormat` → `stage editing`,
    `skipped.single.reason == SkipReason.format`, `stamps.stamped` has the three paths.
  - `GivenAFileWhoseTagsCannotBeRead_WhenLoaded_ThenItIsSkippedAsUnsafe` (`tagWriter.unreadable`).
  - `GivenOnlyOggs_WhenLoaded_ThenItIsUnwritableForItsFormat`.
  - `GivenAGenreTyped_WhenSaved_ThenEveryFileIsWrittenAgainstItsOwnStampAndOneRescanFollows` → 3 writes,
    `expectations` sizes match per-path stamps, `stage saved`, `written 3`, `scanner.requests` length 1.
  - `GivenAGenreTypedThatTwoFilesAlreadyHold_WhenSaved_ThenOnlyTheFilesThatDifferAreWritten` → 1 write, `written 1`.
  - `GivenAnUntouchedMixedYear_WhenGenreIsSaved_ThenNoWriteHoldsAYear`.
  - `GivenOneFileInUse_WhenSaved_ThenTheOthersAreWrittenAndItIsListed` → `stage results`, `written 2`,
    `failed.single.outcome inUse`, one rescan.
  - `GivenAFileInUse_WhenTryAgainAfterItIsFree_ThenOnlyItIsWritten` → after clearing the refusal, `retry()`; writes
    total 3 (no path twice), `stage saved`, `written 3`.
  - `GivenAFileChangedSinceRead_WhenTryAgain_ThenItIsReadAgainAndWrittenAgainstTheNewStamp` → stamp for that path
    changed before retry; its second write's `expected.sizeInBytes` is the new one.
  - `GivenADeniedFile_WhenSaved_ThenItIsListedAndNotRetryable`.
  - `GivenAFileWithNoTrackNumber_WhenATrackTotalIsSaved_ThenItKeepsItsTotalAndIsNoted` → `totalsLeft.single`,
    `failed` empty, `stage results`, `written 3` (the other files and that file's other edits are written).
  - `GivenAccessRefused_WhenSaved_ThenNothingIsWrittenAndItIsEditingWithTheRefusal` (`FakeLibraryAccess` denying).
  - `GivenASaveInFlight_WhenSavedAgain_ThenTheSecondIsIgnored` (`tagWriter.hold`).
  - `GivenTheControllerDisposedMidSave_WhenTheWritesFinish_ThenEveryFileIsWrittenAndTheLibraryRescanned` →
    hold the writer, close the listener subscription, complete the hold, `pumpEventQueue`; 3 writes, 1 rescan.
- [ ] **Step 2: Run** the test file — FAIL.
- [ ] **Step 3: Implement** the controller and provider.
- [ ] **Step 4: Run** — PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: write shared tag edits to many tracks`.

---

### Task 3: The form, its strings and its launcher

**Files:**
- Create: `lib/features/tag_editor/presentation/edit_many_tags_dialog.dart`
- Modify: `lib/features/tag_editor/presentation/edit_tags_launcher.dart` (add `startManyTagEdit`)
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_pt.arb`, regenerate `lib/core/l10n/generated/*`
- Test: `test/features/tag_editor/presentation/edit_many_tags_dialog_test.dart`,
  `test/features/tag_editor/presentation/edit_tags_launcher_test.dart`

**Interfaces:**
- Consumes: Task 2's provider and state; `startTagEdit`; `autofillFieldName`, outcome strings, `Breakpoint`,
  `coverPickerProvider`, `isSupportedCover`, `musicTitleOf`.
- Produces:
  ```dart
  class EditManyTagsDialog extends ConsumerStatefulWidget {
    const EditManyTagsDialog({required this.entries, required this.label, super.key});
    final List<MusicEntry> entries; final String label;
  } // pops the number of files written (int), or null when none
  Future<void> startManyTagEdit(BuildContext context, List<MusicEntry> entries, {required String label});
  ```
- New strings (en; pt translated alongside): `tagEditManySubtitle` `"{label} · {count, plural, =1{1 song} other{{count} songs}}"`,
  `tagEditManyReading` `"Reading {done} of {total}…"`, `tagEditManySaving` `"Saving {done} of {total}…"`,
  `tagEditManyMixed` `"Mixed — leave blank to keep each song's own"`, `tagEditManyMixedCovers` `"Different covers"`,
  `tagEditManyOneAtATime` `"Title and track number are edited one song at a time."`,
  `tagEditManySkipped` `"{count, plural, =1{1 song can't be changed and will be left alone} other{{count} songs can't be changed and will be left alone}}"`,
  `tagEditManySkippedFormat` `"Not an MP3 or FLAC file"`, `tagEditManySkippedUnsafe` `"Its tags can't be changed safely"`,
  `tagEditManyPartly` `"Saved to {written, plural, =0{no songs} =1{1 song} other{{written} songs}}. {failed, plural, =1{1 couldn't be changed:} other{{failed} couldn't be changed:}}"`,
  `tagEditManySaved` `"{count, plural, =1{Tags saved to 1 song} other{Tags saved to {count} songs}}"`,
  `tagEditManyTrackTotalLeft` `"Its track total was left as it was: it has no track number"`,
  `tagEditManyDiscTotalLeft` `"Its disc total was left as it was: it has no disc number"`,
  `musicGroupActions` `"More actions"` (used by Task 4).

Layout and states per spec §4.3: subtitle; loading with `tagEditManyReading`; unwritable text and *Close*; an
`ExpansionTile` with the skipped summary and each `musicTitleOf(entry)` — reason; cover row (thumbnail /
`Icons.album_outlined` for none / `Icons.filter_none` with `tagEditManyMixedCovers` for mixed; *Choose image…*;
*Remove* enabled when `shared.anyCover` and not removed); fields `sharedTextFields` with disc number/total paired, a
mixed field's `hintText: tagEditManyMixed`; `tagEditManyOneAtATime` and `autofillNotWritableFields` under the form.
*Save* enabled when `hasSharedChanges && sharedNumberProblems.isEmpty`. While `saving`: fields read-only,
`tagEditManySaving`, `PopScope(canPop: false)`, Cancel disabled, `barrierDismissible` false in the launcher's
`showDialog`. `results`: fields read-only, `tagEditManyPartly`, failed list (name — outcome message as
`EditTagsDialog._outcomeMessage`), totals-left list; actions *Close* (pops `written`) and *Try again* when any
`retryable`. `saved` pops `written`. Totals left are shown only in `results` (Task 2 ends there when any were left,
even with no failure — the spec leaves the place to the builder; recorded as a call in the PR).

`startManyTagEdit`: empty → return; one → `startTagEdit(context, entries.single)`; else `showDialog<int>` with
`barrierDismissible: false`; on a result > 0, snackbar `tagEditManySaved(count)` (messenger and string taken before
the await, as `startTagEdit` does).

- [ ] **Step 1: Write the failing widget tests** (`pumpHarness` as `edit_tags_dialog_test.dart`; three FLAC entries):
  - `GivenThreeSongsOfOneAlbum_WhenOpened_ThenTheAlbumIsFilledAndTitleAndTrackNumberAreAbsent` → `find.text('OK
    Computer')` in the album field; no field labelled with `autofillFieldName(title)`/`trackNumber`;
    `find.text('Title and track number are edited one song at a time.')`.
  - `GivenDifferentYears_WhenOpened_ThenTheYearShowsTheMixedHint`.
  - `GivenNothingChanged_WhenOpened_ThenSaveIsDisabled`; `GivenAGenreTyped_ThenSaveIsEnabled`.
  - `GivenAYearOf0_WhenTyped_ThenSaveIsDisabledAndTheFieldSaysWhy`.
  - `GivenAnOggAmongThem_WhenOpened_ThenOneSongIsSaidToBeLeftAlone` → `'1 song can't be changed and will be left
    alone'`; expanding shows `'Not an MP3 or FLAC file'`.
  - `GivenDifferentCovers_WhenOpened_ThenDifferentCoversIsShown`.
  - `GivenAPngPicked_WhenSaved_ThenEveryFileGetsTheCover` (`FakeCoverPicker.next` = PNG bytes).
  - `GivenOneFileInUse_WhenSaved_ThenTheResultListsItAndOffersTryAgain` → `'Saved to 2 songs. 1 couldn't be
    changed:'`, the in-use message, `Try again`; the genre field is read-only.
  - `GivenAWriteInFlight_WhenBackIsPressed_ThenTheDialogStays` (`tagWriter.hold`; `tester.binding.handlePopRoute()`).
  - `GivenAllWritten_WhenSaved_ThenTheDialogClosesAndSaysTagsSavedTo3Songs` (through `startManyTagEdit`).
  - Launcher: `GivenOneEntry_WhenStarted_ThenTheOneTrackFormOpens` → `find.byType(EditTagsDialog)`.
- [ ] **Step 2: Run** them — FAIL.
- [ ] **Step 3: Add the strings** to both ARB files with descriptions; run `flutter gen-l10n`.
- [ ] **Step 4: Implement** the dialog and `startManyTagEdit`.
- [ ] **Step 5: Run** the new tests and `test/core/l10n/catalog_parity_test.dart` — PASS; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat: edit the tags of many tracks in one form`.

---

### Task 4: The album and artist menu

**Files:**
- Modify: `lib/features/library/domain/music_grouping.dart` (add `entriesOfArtist`)
- Modify: `lib/features/playback/presentation/music_rows.dart` (`MusicGroupMenu`; `_GroupActions` gains ⋮, loses
  the autofill icon; `_GroupRows`/`_GroupGrid` wrap their tile in the menu)
- Test: `test/features/library/domain/music_grouping_test.dart`,
  `test/features/playback/presentation/music_library_view_test.dart`

**Interfaces:**
- Consumes: `startManyTagEdit` (Task 3), `startAutofill`, `tracksOfAlbum`, `musicLibraryControllerProvider`
  (`AsyncValue<MusicCatalog>`, `.value?.entries`), `musicGroupActions` string, the group's display-name helper the row
  already uses for its title.
- Produces:
  ```dart
  /// Every entry whose album artist is [artist], album by album as inArtistOrder orders them.
  List<MusicEntry> entriesOfArtist(String? artist, List<MusicEntry> library);
  class MusicGroupMenu extends ConsumerWidget {
    const MusicGroupMenu({required this.group, required this.kind, required this.builder, super.key});
    final MusicGroup group; final MusicGroupKind kind;
    final Widget Function(BuildContext context, MenuController menu) builder; // the row, wired to open the menu
  }
  ```

The menu's items: *Autofill tags…* (albums only; `startAutofill(context, ref, gathered, kind: AutofillKind.record)`)
and *Edit tags…* (`startManyTagEdit(context, gathered, label: <group display name>)`), where `gathered` is read from
`musicLibraryControllerProvider` when the item is pressed: album → `tracksOfAlbum(first.album, first.albumArtist,
library)`; artist → `entriesOfArtist(first.albumArtist, library)`; falling back to `group.entries` when the library is
not loaded. Right-click and long press on the row/tile and the ⋮ button (`Icons.more_vert`, tooltip
`musicGroupActions`) open it, as `MusicRowMenu` does. The grid tile's existing `onTap` is kept.

- [ ] **Step 1: Write the failing tests**:
  - `GivenAnArtistWithTwoAlbums_WhenAskedForTheirEntries_ThenBothAlbumsAreReturnedInOrder`.
  - `GivenTheUntaggedArtist_WhenAskedForTheirEntries_ThenOnlyTheUntaggedEntriesAreReturned` (`artist: null`; an
    entry with an artist but no album artist falls back as `entry.albumArtist` does, so check the fixture).
  - `GivenAnAlbumRow_WhenItsMoreButtonIsPressed_ThenEditTagsAndAutofillTagsAreOffered`.
  - `GivenAnArtistRow_WhenItIsRightClicked_ThenEditTagsIsOfferedAndAutofillIsNot`.
  - `GivenAnAlbumOfThreeTracks_WhenEditTagsIsPicked_ThenTheManyTrackFormOpensOverThree` →
    `find.byType(EditManyTagsDialog)` and `find.textContaining('3 songs')`.
  - `GivenAnAlbumRow_WhenListed_ThenItHasNoSeparateAutofillButton` (no `Icons.auto_fix_high_outlined` outside a menu).
- [ ] **Step 2: Run** them — FAIL.
- [ ] **Step 3: Implement** `entriesOfArtist` and `MusicGroupMenu`; wire rows and grid tiles.
- [ ] **Step 4: Run** the two test files and the whole `test/features/playback` folder — PASS.
- [ ] **Step 5: Commit** `feat: open album and artist actions in a menu`.

---

### Task 5: Documents

**Files:** `docs/requirements/Vision Document.md`, `docs/requirements/System Requirements Document.md`,
`docs/requirements/Use Case Specification Document.md`, `README.md`, `docs/site/content/en/_index.md` (and any site
page that copies the tag-editing bullet — `grep -rn "Edit tags" docs/site/content`), `CHANGELOG.md`.

- [ ] **Step 1:** Vision: §1.2 scope sentence per spec §3; **F-19 Edit the tags of several tracks** after F-18; §6
  names `FR-TE` beside `FR-AF`.
- [ ] **Step 2:** SRS: **FR-TE-05 … FR-TE-08** verbatim from spec §3 after FR-TE-04; NFR-03 cites `FR-TE-07`;
  traceability row `F-19 Edit the tags of several tracks | FR-TE-05 … FR-TE-08`.
- [ ] **Step 3:** Use cases: **UC-37** from spec §8 after UC-35 (UC-36 belongs to the genres branch — leave the gap),
  and its traceability row
  `UC-37 Edit the tags of several tracks at once | FR-TE-05 … FR-TE-08`.
- [ ] **Step 4:** README and site overview: extend *Lets you fix a track's tags by hand* with "— or, from an album's
  or an artist's ⋮ menu, the shared tags of all its songs at once; fields they disagree on show as mixed and are left
  alone unless you type in them".
- [ ] **Step 5:** CHANGELOG `[Unreleased]` → `### Added`: edit tags of a whole album or artist (menu, mixed fields,
  title and track number not offered, only changed fields written, skipped formats listed, per-song failures with
  Try again); `### Changed`: the album row's autofill button moved into its new ⋮ menu.
- [ ] **Step 6: Commit** `docs: describe editing many tracks' tags`.

---

### Task 6: Verify and open the pull request

- [ ] **Step 1:** `dart format --set-exit-if-changed lib test` — exit 0.
- [ ] **Step 2:** `flutter analyze` — "No issues found!".
- [ ] **Step 3:** `flutter test` — "All tests passed!".
- [ ] **Step 4:** If `feature/genres` has been merged into `origin/develop`, rebase onto it and re-run steps 1–3
  (conflicts expected in `music_rows.dart`, the use-case document and CHANGELOG; keep both sides).
- [ ] **Step 5:** Push `feature/edit-many-tags`; open a PR into `develop` titled
  `feat: edit the tags of a whole album or artist`, body summarising the feature, the spec and plan paths, and the
  test results, ending with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
