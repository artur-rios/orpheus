# Select several songs, and edit their tags — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every song list lets the owner select several songs (touch and hold, Ctrl-click, Shift-click) and open the
step-2 tag form over them from a selection bar or a right-click.

**Architecture:** A pure `SongSelection` value and a Riverpod holder keep the selected paths, the anchor and the list
identity (`selectionScope`) they belong to; `MusicTrackList` renders tick boxes and a bar and routes gestures; the
existing back handler in `lib/app.dart` clears a selection first; *Edit tags…* calls the existing `startManyTagEdit`.

**Tech Stack:** Flutter 3.47, Riverpod `Notifier`, `flutter_test`, ARB localisations (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-18-select-songs-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; providers only in `core/di/providers.dart`.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`; use `test/support` (`Harness`,
  `pumpHarness`, `entry()`, the fakes).
- Every new string in both `app_en.arb` and `app_pt.arb` with an `@key` description and the same placeholders; keys
  prefixed `musicSelection…`; regenerate with `flutter gen-l10n`.
- No colour literals outside `lib/core/theme/`.
- Formatting: new files `dart format`-clean; edited files keep their surrounding style (the local Dart 3.13.5
  formatter reflows ~80 unrelated committed files — never run it tree-wide).
- With nothing selected, every list behaves exactly as today (tap plays; ⋮ and right-click open the song's menu).
- Album, artist and genre rows (`MusicGroupMenu`) are unchanged, touch and hold included.
- The row's ⋮ button always opens the song's own menu.
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A tap with nothing selected still plays** — the regression the owner would feel first. (Task 2
   `…NothingSelected_WhenARowIsTapped_ThenItPlays…`.)
2. **Going from Songs into an album, or between albums, ends the selection** although the same list element is
   reused. (Task 2 `…AnotherAlbumOpened…`.)
3. **A rescan while selecting** keeps the selection and drops only songs that vanished. (Task 1 retain-only, Task 2
   `…SongsChangeInTheSameList…`.)
4. **Back on Android while selecting** clears the selection and does not also clear the search or go up a level.
   (Task 4.)
5. **Edit tags over exactly the selection, in list order** — not the whole list, not the right-clicked row only.
   (Task 3.)

---

### Task 1: The selection and its holder

**Files:**
- Create: `lib/features/playback/domain/song_selection.dart`
- Create: `lib/features/playback/application/song_selection_controller.dart`
- Modify: `lib/core/di/providers.dart` (add `songSelectionProvider`)
- Test: `test/features/playback/domain/song_selection_test.dart`,
  `test/features/playback/application/song_selection_controller_test.dart`

**Interfaces — Produces:**
```dart
/// Immutable. Order for actions comes from the list, never from `paths`.
class SongSelection {
  const SongSelection({this.scope, this.paths = const {}, this.anchor});
  static const SongSelection none = SongSelection();
  final Object? scope;            // the list identity it was made in; null when nothing is selected
  final Set<String> paths;
  final String? anchor;           // last path toggled, on or off
  bool get isActive;              // paths.isNotEmpty
  bool isActiveIn(Object scope);  // isActive && this.scope == scope
  SongSelection toggle(Object scope, String path);          // another scope → starts fresh in this one with [path]
  SongSelection rangeTo(Object scope, String path, List<String> order); // anchor null or absent from order → toggle
  SongSelection selectAll(Object scope, List<String> order);
  SongSelection retainIn(Object scope, List<String> order); // other scope → none; drops absent paths; anchor cleared if absent; empty → none
}
class SongSelectionController extends Notifier<SongSelection> {
  void toggle(Object scope, String path);
  void rangeTo(Object scope, String path, List<String> order);
  void selectAll(Object scope, List<String> order);
  void retainIn(Object scope, List<String> order);
  void clear();
}
final songSelectionProvider = NotifierProvider<SongSelectionController, SongSelection>(SongSelectionController.new);
```

- [ ] **Step 1: Write the failing tests:**
  - `GivenNothing_WhenASongIsToggled_ThenItIsSelectedInThatScopeAndIsTheAnchor`.
  - `GivenASelectedSong_WhenToggledAgain_ThenTheSelectionEnds` (`== none`, `isActive` false).
  - `GivenASelectionInSongs_WhenASongIsToggledInAnAlbum_ThenOnlyThatSongIsSelectedInTheAlbum`.
  - `GivenAnAnchorAtB_WhenRangeToE_ThenBThroughEAreAdded` (order `a..f`, existing `a` stays) and the backward case
    `…RangeToAFromD_ThenAThroughDAreAdded`.
  - `GivenNoAnchor_WhenRangeTo_ThenItActsAsAToggle`.
  - `GivenSomeSelected_WhenSelectAll_ThenEverySongInTheOrderIsSelected`.
  - `GivenSelectedSongsOneOfWhichVanished_WhenRetained_ThenOnlyTheVanishedOneDrops` (anchor cleared when it was it).
  - `GivenEverySelectedSongVanished_WhenRetained_ThenTheSelectionEnds`.
  - `GivenASelectionInAnotherScope_WhenRetainedInThisOne_ThenTheSelectionEnds`.
  - Controller: `GivenASelection_WhenCleared_ThenNothingIsSelected`, and one test each that the controller delegates
    toggle / rangeTo / selectAll / retainIn.
- [ ] **Step 2: Run** both files — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: hold a selection of songs`.

---

### Task 2: Selecting in a song list

**Files:**
- Modify: `lib/features/playback/presentation/music_rows.dart` (`MusicTrackList`, `MusicRowMenu`)
- Modify: `lib/features/playback/presentation/music_browser.dart`, `lib/features/playback/presentation/genres_view.dart`,
  `lib/features/playback/presentation/music_library_view.dart`, `lib/features/playback/presentation/search_results_view.dart`
- Modify: `lib/core/l10n/app_en.arb`, `app_pt.arb`, regenerated `lib/core/l10n/generated/*`
- Test: `test/features/playback/presentation/music_track_list_test.dart` (new)

**Interfaces:**
- Consumes: Task 1.
- Produces: `MusicTrackList({required entries, required numbered, required Object selectionScope, emptyMessage})`;
  `MusicBrowser` gains `required Object selectionPlace` (library view passes `'music'`; genres view passes
  `('genre', <genre name>)`), and builds each list's scope as `(selectionPlace, state.view, state.artist,
  state.album, state.inAlbum)`; `SearchResultsView` passes `('search', term.trim(), field)`.
- Strings: `musicSelectionCount` `"{count, plural, =1{1 selected} other{{count} selected}}"`, `musicSelectionAll`
  `"Select all"`, `musicSelectionStop` `"Stop selecting"`, `musicSelectionSelect` `"Select {title}"` (tick box
  semantics), plus Task 3's `musicSelectionEditTags` `"{count, plural, =1{Edit tags of 1 song…} other{Edit tags of {count} songs…}}"`
  and `musicSelectionLabel` `"Selected songs"` (add all six here).

Behaviour (spec §3): the list watches `songSelectionProvider`; `isActiveIn(selectionScope)` decides the mode. In
`build`/after frame, when the provider's selection is active in this scope, call `retainIn(scope, paths of entries)`
(post-frame, never during build). A selection active in another scope is ended by the list on its first frame
(`retainIn` does it). Row gestures: `onLongPress` → `toggle`; `onTap` → with Shift held `rangeTo`, with Ctrl held
`toggle`, else selecting ? `toggle` : play (unchanged). Keys from `HardwareKeyboard.instance.isShiftPressed` /
`isControlPressed`. Leading slot while selecting: a `Checkbox` (value = selected, `onChanged` toggles, semantic label
`musicSelectionSelect(title)`). The bar (while selecting) above the `ListView`: `IconButton(Icons.close, tooltip
musicSelectionStop) → clear`, `Text(musicSelectionCount(n))`, `TextButton(musicSelectionAll)` hidden when all are
selected, and a slot Task 3 fills with *Edit tags…*. A `Focus` + `CallbackShortcuts({Escape: clear})` wraps the list;
its node requests focus when a selection starts. `MusicRowMenu` drops `onLongPressStart`.

- [ ] **Step 1: Write the failing widget tests** (Songs list of 4 entries `a..d` via `pumpHarness`, as
  `music_library_view_test.dart` does; reuse its way of asserting a play):
  - `GivenNothingSelected_WhenARowIsTapped_ThenItPlays`.
  - `GivenNothingSelected_WhenARowIsHeld_ThenItIsSelectedAndTheBarSays1Selected` (and no play).
  - `GivenOneSelected_WhenAnotherRowIsTapped_ThenItIsSelectedAndNothingPlays` → `2 selected`.
  - `GivenASelectedRow_WhenItsTickBoxIsTapped_ThenItIsDeselectedAndSelectingEnds`.
  - `GivenNothingSelected_WhenARowIsCtrlClicked_ThenItIsSelected` (`tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft)` around the tap).
  - `GivenBSelected_WhenDIsShiftClicked_ThenBThroughDAreSelected` → `3 selected`.
  - `GivenSomeSelected_WhenSelectAllIsPressed_ThenAllFourAreSelectedAndSelectAllIsGone`.
  - `GivenASelection_WhenStopSelectingIsPressed_ThenTheBarIsGone`; `…WhenEscapeIsPressed_ThenTheBarIsGone`.
  - `GivenASelectionInSongs_WhenAnAlbumIsOpened_ThenNothingIsSelectedThere` (Review Focus 2; same harness as
    `music_library_view_test.dart`, switching view/opening an album) and `…AnotherAlbumOpened…` between two albums.
  - `GivenASelection_WhenTheSongsChangeInTheSameList_ThenOnlyTheVanishedSongDrops` (Review Focus 3; replace the
    library with one entry fewer and pump).
  - `GivenNothingSelected_WhenASongRowIsHeld_ThenItsMenuDoesNotOpen` (no `Edit tags…` item) and
    `GivenAnAlbumRow_WhenHeld_ThenItsMenuOpens` (group rows unchanged).
- [ ] **Step 2: Run** — FAIL. **Step 3: Add the strings** and `flutter gen-l10n`. **Step 4: Implement.**
- [ ] **Step 5: Run** the new file, `test/features/playback`, `test/core/l10n/catalog_parity_test.dart` — PASS;
  `flutter analyze` clean. Update any existing test that relied on touch-and-hold opening a song's menu to use the ⋮
  button or right-click instead.
- [ ] **Step 6: Commit** `feat: select several songs in a list`.

---

### Task 3: Edit the selection's tags

**Files:**
- Modify: `lib/features/playback/presentation/music_rows.dart`
- Modify: `lib/features/tag_editor/presentation/edit_tags_launcher.dart` (return what was written)
- Test: `test/features/playback/presentation/music_track_list_test.dart`,
  `test/features/tag_editor/presentation/edit_tags_launcher_test.dart`

**Interfaces:**
- Consumes: Task 2's list and strings; `startManyTagEdit`, `startTagEdit`.
- Produces: `startManyTagEdit` and `startTagEdit` return `Future<bool>` — `true` when at least one file was written
  (existing callers ignore it).

Behaviour: the bar's last slot is `FilledButton.tonal(musicSelectionEditTags(n))`; a right-click on a selected row
while selecting opens a menu (a `MenuAnchor` at the click position) holding one item, `musicSelectionEditTags(n)`; a
right-click on an unselected row opens the song's own menu as today; the ⋮ button always opens the song's own menu.
Both call `startManyTagEdit(context, selected, label: l10n.musicSelectionLabel)` with `selected` = the list's entries
whose path is selected, in the list's order; when it returns `true`, `clear()`.

- [ ] **Step 1: Write the failing tests:**
  - `GivenTwoOfFourSelected_WhenEditTagsInTheBarIsPressed_ThenTheFormOpensOverThoseTwoInListOrder` →
    `EditManyTagsDialog` with `Selected songs · 2 songs`, and the dialog's `entries` are `[b, d]` for selection order
    `d, b`.
  - `GivenOneSelected_WhenEditTagsIsPressed_ThenTheOneTrackFormOpens` → `EditTagsDialog`.
  - `GivenASelection_WhenASelectedRowIsRightClicked_ThenTheMenuOffersEditTagsOf2Songs`.
  - `GivenASelection_WhenAnUnselectedRowIsRightClicked_ThenItsOwnMenuOpens` (holds `Play`, `Edit tags…`).
  - `GivenASelection_WhenARowsMoreButtonIsPressed_ThenTheSongsOwnMenuOpens`.
  - `GivenASelection_WhenTheFormSavesSongs_ThenTheSelectionEnds` (FakeTagWriter files for both; type a genre; Save).
  - `GivenASelection_WhenTheFormIsCancelled_ThenTheSelectionStays`.
  - Launcher: `GivenAManyTrackSave_WhenItWrites_ThenTheLauncherAnswersTrue`; `…Cancelled_ThenFalse`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** the two files and `test/features/tag_editor`,
  `test/features/playback` — PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: edit the tags of the selected songs`.

---

### Task 4: Back ends a selection first

**Files:**
- Modify: `lib/app.dart` (the `PopScope` back handler)
- Test: `test/features/shell/presentation/shell_screen_test.dart` (where Back is already tested)

Behaviour: `canPop` is also false while `songSelectionProvider` is active; in `onPopInvokedWithResult`, before the
search check, an active selection is cleared and the handler returns.

- [ ] **Step 1: Write the failing tests:** `GivenASelectionInsideAnAlbum_WhenBackIsPressed_ThenTheSelectionEndsAndTheAlbumStaysOpen`;
  `GivenASelectionInSearchResults_WhenBackIsPressed_ThenTheSelectionEndsAndTheSearchStays`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** the shell tests — PASS.
- [ ] **Step 5: Commit** `feat: end a selection with back`.

---

### Task 5: Documents

**Files:** `docs/requirements/Vision Document.md`, `docs/requirements/System Requirements Document.md`,
`docs/requirements/Use Case Specification Document.md`, `README.md`, `docs/site/content/en/docs/overview/_index.md`,
`CHANGELOG.md`.

- [ ] **Step 1:** Vision **F-20 Select several songs**; SRS **FR-UX-11**, **FR-UX-12**, **FR-TE-09** as in spec §6,
  amending any FR-UX row that says touch and hold opens a song's menu; traceability `F-20 → FR-UX-11, FR-UX-12,
  FR-TE-09`.
- [ ] **Step 2:** **UC-38: Select several songs and edit their tags** after UC-37 (main flow and alternative flows per
  spec §6), traceability row; any UC that says touch and hold opens a song's menu updated.
- [ ] **Step 3:** README feature bullet, roadmap row for UC-38 (no issue; link the use case, as UC-37) and status line
  `UC-01 to UC-38`; docs site overview row; CHANGELOG `[Unreleased]` `### Added` (selection, edit tags of the
  selection) and `### Changed` (touch and hold on a song selects it; its menu is on ⋮ or a right-click).
- [ ] **Step 4: Commit** `docs: describe selecting several songs`.

---

### Task 6: Verify and open the pull request

- [ ] **Step 1:** Once PR #59 is merged, `git fetch` and `git rebase origin/develop` (step 2's commits drop out as
  already merged).
- [ ] **Step 2:** `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; new files format-clean.
- [ ] **Step 3:** Push `feature/select-songs`; PR into `develop` titled `feat: select several songs and edit their
  tags`, body as PR #59's (summary, testing, calls to check), ending `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
