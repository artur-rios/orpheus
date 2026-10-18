# Edit the tags of several tracks at once — design

Status: draft for review · 2026-10-18 · branch `feature/edit-many-tags` · use case UC-37

## 1. Intent

The owner fixes the tags of many songs at once: a misspelt album name on twelve tracks, an artist written two ways, a
missing year or genre on a whole record, one cover for the whole album. Today *Edit tags…* (UC-35) does one track at a
time, and twelve dialogs for one typo is what makes the owner give up and open another program.

This is step 2 of five agreed library steps. Step 3 adds selecting songs in a list and *Edit tags* on the selection
(right-click); it reuses the form built here unchanged. So the form is built over **any list of tracks**, and this step
opens it from an album's or an artist's actions.

Success: from an album or an artist, one form, one *Save*, and every song shows the fix without a scan — and nothing the
owner did not change, in any song, is touched. A song that could not be written is named with its reason, and the rest
stay saved.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| Where | From an album's and an artist's actions — the rows of Albums and Artists, list and grid. Selecting songs is step 3. |
| Which fields | Depends on how many songs, not on where the form was opened: with more than one, **title** and **track number** are hidden (one value for every song is almost always a mistake). Artist, album artist, album, track total, disc number and total, year, genre and cover stay. |
| Disagreeing songs | A field where the songs differ shows as **mixed** and is left alone unless the owner types in it. |
| Only what changed | Only the fields the owner changed are written, to every song that can hold them. |
| Cover | One picture for all shows; different pictures show as mixed; none shows empty. *Choose image…* puts it in every song; *Remove* takes it out of every song that has one. |
| Formats | Songs that are not MP3 or FLAC (or whose tags can't be changed safely) are listed before the owner starts, and skipped. |
| Results | *Save* writes the songs one after another, with a count. All written → the form closes and says *Tags saved to 12 songs*. Some failed → the form stays, lists only those with their reason, the written ones stay written, and the failed ones can be tried again. |
| Menu | Album and artist rows get the same kind of menu songs have — a ⋮ button, a right-click and a long press — holding *Edit tags…*, and *Autofill tags…* on albums. |
| Which tracks | Every track of the album or artist **in the library**, even when the row is shown inside a narrower view (a genre, once step 1 lands) — fixing a name from inside *Rock* must not split the record in two. Editing only the tracks in view is step 3's selection. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above; a form step 3 can open over any list of `MusicEntry` without changing it; the same
  writer, safeguards and rescan as UC-34 and UC-35.
- **Non-goals:** selecting songs (step 3); editing title or track number across songs (renumbering a record); fields
  beyond the ten text/number fields and the cover; any format but MP3 and FLAC; undo.
- **Anti-goals** (a failure even if it works): a song gets a value the owner never typed (a mixed field rewritten with
  one song's value, or with blank); one failing song loses the others' writes, or the owner's typing; the owner cannot
  tell which songs were not changed and why; the one-track editor changes behaviour.

## 3. Product and documentation changes

All in the same pull request.

- **Vision Document**
  - §1.2 Scope: "a record at a time by autofill, or one track at a time by hand" becomes "…by autofill, or by hand for
    one track or many at once"; it stays not a library manager (no renaming or moving).
  - **F-19 Edit the tags of several tracks** — new feature row.
  - §6 Out of scope: "tag editing beyond an autofill the owner confirms (`FR-AF`)" names `FR-TE` beside it (it already
    should since 1.4.0).
- **System Requirements Document** — four new rows in the `FR-TE` section:
  - **FR-TE-05** The owner must be able to edit, from an album's or an artist's menu, the artist, album artist, album,
    track total, disc number and total, year, genre and front cover of all its tracks in one form. A field the tracks
    disagree on must be shown as mixed; title and track number are not offered for more than one track.
  - **FR-TE-06** Tracks Orpheus cannot write (`FR-TE-02`) must be named before the owner saves and left alone; a field
    none of the tracks can hold is not editable.
  - **FR-TE-07** Only the fields the owner changed may be written, to each track that can hold them, under the rules
    of `FR-TE-03`, each track measured against itself as it was read; a mixed field left alone is written to none, and
    a track that already holds the value is not written for it.
  - **FR-TE-08** Each track that could not be written must be named with its reason as in `FR-AF-07`, without undoing
    the tracks that were; those in use, failed or changed since read can be tried again. The library updates without
    the owner starting a scan.
  - **NFR-03** gains `FR-TE-07` beside `FR-TE-03`. Traceability: `F-19 → FR-TE-05 … FR-TE-08`.
- **Use Case Specification** — **UC-37: Edit the tags of several tracks at once** (§8), and its traceability row.
  (UC-36 is the genres step's.)
- **README** and **docs site overview** — the *Lets you fix a track's tags by hand* bullet gains the album/artist form.
- **CHANGELOG** — `### Added` under `[Unreleased]`.

No permission, manifest or CI change.

## 4. Architecture

Inside the existing `lib/features/tag_editor/`, beside the one-track editor, which is not changed except where noted.

```
lib/features/tag_editor/
  domain/shared_tags.dart                what several files hold in common, and each file's edits
  application/many_tag_edit_controller.dart   load → edit → save → retry, over a list of tracks
  presentation/edit_many_tags_dialog.dart    the form
  presentation/edit_tags_launcher.dart       + startManyTagEdit(context, entries, label)
lib/features/playback/presentation/
  music_rows.dart                        + the album/artist menu (MusicGroupMenu)
```

### 4.1 Domain — `shared_tags.dart` (pure, reuses `tag_edits.dart`)

```dart
/// The fields the form over several tracks offers, in order.
const List<AutofillField> sharedTextFields = [
  artist, albumArtist, album, trackTotal, discNumber, discTotal, year, genre,
];

/// What a field holds across the files.
sealed class Shared<T> { }            // Same(value) — T? (null: none of them has it) | Mixed()

class SharedTags {
  factory SharedTags.of(List<FileTags> files);
  final Map<AutofillField, Shared<Object>> values;   // for sharedTextFields
  final Shared<Uint8List> cover;
  final Set<AutofillField> writable;                  // union: at least one file can hold it
}

/// The text a field starts with in the form: the shared value as text, or '' when mixed or none.
String sharedText(SharedTags shared, AutofillField field);

/// The edits [form] makes to one [file], given what the form started from.
FileEdits editsFor(FileTags file, SharedTags shared, TagForm form);

class FileEdits {
  final Map<AutofillField, Object?> values;        // empty: nothing to write to this file
  final Set<AutofillField> leftForMissingNumber;   // totals not written — see below
}
```

`TagForm`, `CoverChoice`, `numberProblem` and `isSupportedCover` are reused from `tag_edits.dart`.

Rules, each a unit test:

- **Same or mixed.** A field is `Same(v)` when every file holds the same value `v` for it (an absent tag counts as a
  value, `null`), `Mixed` otherwise. Values are compared as `FileTags.values` holds them, so a file whose genre is
  `Rock; Pop` differs from one holding `Rock`. Cover: `Same(bytes)` if every file has byte-for-byte the same picture,
  `Same(null)` if none has one, `Mixed` otherwise. Only files the form edits (§4.2) are compared.
- **Changed.** A field is changed when its typed text, trimmed, differs from `sharedText`. So a mixed field left blank
  is no change, and typing in it sets every file to what was typed.
- **Value.** As `tagEdits`: a text field trimmed to empty is `null` (remove); a number must pass `numberProblem`.
  Clearing a field removes it only when it was `Same`, since a mixed field starts blank. *(My call: there is no way to
  remove a mixed field from every song at once; out of scope.)*
- **Per file.** A changed field is in a file's edits only if the file can hold it (`file.writable`) and does not
  already hold that value (`03` over `3` is no change, as in `tagEdits`). A file with an empty `values` is not written.
- **Cover per file.** `keep` → absent; `remove` → `null` where the file has a cover; `replace(bytes)` → the bytes where
  the file's cover differs.
- **A total without its number.** ID3 cannot hold `/12`, and the writer refuses it. If a file's edits would give it
  a track (or disc) total while its own number is absent and unchanged, that file's total edit is dropped and the total
  is named in `leftForMissingNumber`; the file's other edits are still written. *(My call, so that one untracked song
  does not block a whole album's track total.)* The owner clearing the disc number while the songs would keep a disc
  total — typed non-blank, or left alone and held by some song, mixed included — is not this case but a form error
  on the disc number (`totalWithoutNumber`), as for one track.
- **Form-level number problems.** A changed number field is checked with `numberProblem` as today; *Save* is
  disabled while any field has a problem. A cleared disc number under a kept total is a form error, as above; a total
  given to a file that has no number of its own is per file, not a form error.

### 4.2 Application — `ManyTagEditController`

An auto-disposed `Notifier<ManyTagEditState>`, started by the dialog with `load(List<MusicEntry> entries)`.

```
loading ──read all──▶ editing ──save──▶ saving ──all written──▶ saved
             │           ▲                 │
             └ none                        └── some failed ──▶ results ──Try again──▶ saving
               editable → unwritable                       (form read-only; Try again saves the failed ones)
```

- **load** reads the files one after another, publishing progress (`read` of `total`). For each: not
  `canWriteTagsTo` → skipped (format); else `fileStamps.stamp` then `tagWriter.inspect`; `writable` empty, or either
  throwing (logged) → skipped (unsafe). The rest are the **files being edited**, each with its entry, stamp and
  `FileTags`. None left → `unwritable`. Otherwise `editing` with `SharedTags.of` those files and the skipped list.
- **save(TagForm form)**: one at a time (a second tap is ignored).
  1. Everything it needs read from `ref` first — access, writer, scan controller — so a confirmed save finishes, and
     is followed by a rescan, even if the dialog goes away.
  2. `libraryAccessController.ensureWritable()`; refused → back to `editing` with the refusal; nothing written.
  3. For each file still being edited, in library order: `editsFor`; empty → done with nothing to write; else
     `tagWriter.write(path, values, expected: stamp)`. Progress (`done` of `total`) is published as it goes.
  4. After the last file: if any was written, one `rescanSoon()`.
  5. Every file written or with nothing to write leaves the set; what is left is those that failed. None failed →
     `saved` (with the count written, and any `leftForMissingNumber` notes). Some failed → a separate `results`
     stage: the count written, each failure (entry and `WriteOutcome`), and the notes. The form saved is kept as it
     was and is **read-only** from then on. *(My call: a new value typed after part of the songs were written would
     reach only the failed ones, and change detection would be measured against a `SharedTags` the written songs no
     longer match. To change something else, the owner closes and opens the form again.)*
- **Try again** is `save` with the same form over the failed files. A file refused as `changedSinceRead` is stamped
  and inspected again first, then given the same edits against what it holds now. *(My call: the owner's edit is
  "album is X", which means the same over the new contents; it is what *Reload* and retyping would do.)* The form's
  `SharedTags` is not recomputed — the form keeps showing what it started from and what the owner typed.
- `denied` and `unsupported` are listed and not retried.

### 4.3 Presentation

**Menu.** `MusicGroupMenu`, the album/artist counterpart of `MusicRowMenu`: a `MenuAnchor` opened by a ⋮ button in
`_GroupActions` (tooltip *More*), a right-click and a long press on the row or the grid tile. Items: *Autofill tags…*
on albums (then `startAutofill` as today), *Edit tags…* on both (`startManyTagEdit(context, entries, label)`),
where `label` is the group's display name and `entries` are gathered from the **whole library** at the moment the item
is picked, not taken from `group.entries`: for an album, `tracksOfAlbum(first.album, first.albumArtist, library)`; for
an artist, every entry whose album artist is the first entry's, in `inArtistOrder` order (a small domain helper beside
`artistOf` that returns the entries). On develop the two are the same tracks; once genres lands, a row inside a genre
holds only that genre's tracks, and the owner chose the whole album or artist. The album row's autofill icon button moves into this menu. *(My call: the
row would otherwise hold four buttons, too many on a phone.)*

**Launcher.** `startManyTagEdit(context, entries, label)`: no entries → nothing; one entry → `startTagEdit` (the
one-track form, title and track number included); several → `EditManyTagsDialog`. On `saved`, or on closing after a
partial save, a snackbar: *Tags saved to N songs* (plural), when N > 0.

**Dialog.** `EditManyTagsDialog`, adaptive like `EditTagsDialog` (full screen below 600 wide, else about 480 wide).

- Title *Edit tags*; beneath, the label and the count (*Abbey Road · 17 songs*).
- Loading: a progress indicator and *Reading 3 of 17…*.
- Unwritable (none editable): `autofillNothingWritable` or `autofillUnsafeTags` (unsafe if any was unsafe), and *Close*.
- Skipped songs, when there are any: one line above the form — *3 songs can't be changed and will be left alone* — that
  expands to each song's name and reason (*Not an MP3 or FLAC file* / *Its tags can't be changed safely*).
- Form: the cover (thumbnail, a placeholder for none, a *Different covers* placeholder for mixed; *Choose image…*;
  *Remove* enabled when any edited file has a cover), then artist, album artist, album, track total, disc number and
  total in a pair, year, genre. A mixed field is empty with the hint *Mixed — leave blank to keep each song's own*.
  One line under the form: *Title and track number are edited one song at a time.* A field none can hold is
  disabled, named as today with `autofillNotWritableFields`.
- Actions: *Cancel* and *Save*, enabled once something changed and no number is invalid.
- Saving: the form is read-only, *Save* shows a progress indicator and *Saving 5 of 17…*; the dialog cannot be
  dismissed (Cancel disabled, back/Escape/barrier ignored) until the loop ends. *(My call: closing mid-way would hide
  which songs were written; the writes are local and short.)*
- After a partial save: *Saved to 14 songs. 3 couldn't be changed:* and each failed song's name with its reason, using
  the existing outcome messages (`autofillOutcomeChanged`, `…InUse`, `…Denied`, `…Failed`, `autofillUnsafeTags` for
  unsupported). The fields stay visible and read-only. Actions: *Close* and, when any failure is retryable, *Try
  again* (no *Save*). Android refusal (nothing written yet): back to an editable form, as UC-35.
- Notes for `leftForMissingNumber`: listed the same way (*Its track total was left as it was: it has no track
  number*), in the result list or, after a full save, as part of the snackbar's message (*Tags saved to 17 songs; 2
  kept their track total*). *(Builder's choice of exact wording.)*

**Strings.** Field labels and outcome messages reuse existing keys. New keys in `app_en.arb` and `app_pt.arb` with
descriptions (the parity test checks both): the *More* tooltip, the song count, reading and saving progress, mixed hint,
different covers, one-at-a-time note, skipped summary and its two reasons, partial-save summary, the saved-to-N
snackbar, the total-left notes (track and disc). Names are the builder's, prefixed `tagEditMany…`.

## 5. Data flow

```
album/artist menu ─▶ startManyTagEdit ─▶ EditManyTagsDialog ─▶ ManyTagEditController.load
                                                                 └─ per file: stamp, TagWriter.inspect
                                         owner edits │ TagForm      → SharedTags + skipped
                                                     ▼
                                 ManyTagEditController.save(form)
                                   ├─ ensureWritable (Android, once)
                                   ├─ per file: editsFor → TagWriter.write(expected: its stamp)
                                   └─ any written ─▶ ScanController.rescanSoon (once) ─▶ every screen
```

## 6. Error handling

| Case | What the owner sees |
| --- | --- |
| Some songs not MP3/FLAC, or unsafe | Listed above the form, left alone. |
| No song can be edited | The reason, and *Close* — nothing to save. |
| Field no song can hold | Disabled, named under the form. |
| Field some songs can't hold | Written to those that can; no message. |
| Invalid number | Inline under the field; *Save* disabled. |
| Picked file not JPEG/PNG | Cover unchanged; inline message (as UC-35). |
| A song has no track/disc number and a total is set | That song keeps its total; noted; its other edits written. |
| Song in use / failed | Listed with the reason; *Try again*. |
| Song changed by another program | Listed; *Try again* reads it again and applies the same edits. |
| Song denied / unsupported | Listed; not retried. |
| Android write access refused | Nothing written; refusal and, if permanent, the settings action. |
| `inspect` throws | That song is skipped as unsafe, logged. |

## 7. Testing

- `test/features/tag_editor/domain/shared_tags_test.dart` — same / mixed / none for text, numbers, several-valued
  fields and the cover; union of writable; changed vs not (mixed left blank, same retyped with spaces); per-file
  skipping of fields a file can't hold and values it already holds; cover per file; total without number dropped per
  file with the note, other edits kept; disc number cleared with totals present.
- `test/features/tag_editor/application/many_tag_edit_controller_test.dart` — fake writer, stamps and scan controller:
  skipped by extension, by empty `writable` and by `inspect` throwing; none editable → unwritable; all written →
  `saved` and exactly one `rescanSoon`; mixed outcomes → written ones not rewritten on *Try again*, failed ones listed;
  `changedSinceRead` re-inspected on retry; nothing to write for a file → not written, not a failure; refused access
  → nothing written; a second save ignored while saving; the loop finishes and rescans after the controller is
  disposed mid-save.
- `test/features/tag_editor/presentation/edit_many_tags_dialog_test.dart` — shared values prefilled, mixed shown with
  the hint, title and track number absent; *Save* disabled until a change; skipped list; cover mixed / remove /
  choose; partial result list and *Try again*; saving blocks dismissal; saved closes with the snackbar.
- `edit_tags_launcher` — one entry opens the one-track form.
- `music_rows` widget test — the album and artist menus, by ⋮ and by right-click, hold *Edit tags…* (and *Autofill
  tags…* on albums only).
- `music_grouping` — the artist-entries helper: every entry by that album artist, the untagged group included, in
  artist order.
- `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`.

## 8. UC-37: Edit the tags of several tracks at once

| Field | Value |
| --- | --- |
| **ID** | UC-37 |
| **Name** | Edit the tags of several tracks at once |
| **Actors** | Owner, Local filesystem, Host platform |
| **Description** | The owner opens one form over all of an album's or an artist's tracks, changes what they want, and only what they changed is written to each track. |
| **Preconditions** | The library holds the album or artist, with more than one track. |
| **Postconditions** | In each track Orpheus could write, exactly the fields the owner changed hold what they typed, and the library shows it. No other tag, and no track the owner was told is skipped, has changed. |
| **Requirements** | FR-TE-05, FR-TE-06, FR-TE-07, FR-TE-08 |

Main flow:

1. The owner picks *Edit tags…* from an album's or an artist's menu — its ⋮ button, a right-click or a long press.
2. The application reads each track's own tags and cover, and notes its size and time (`FR-TE-05`).
3. The form shows artist, album artist, album, track total, disc number and total, year, genre and cover — what the
   tracks share, and *mixed* where they differ — and names any track it will leave alone (`FR-TE-06`).
4. The owner changes what they want; *Save* is offered once something changed and every number is valid.
5. The owner presses *Save*. Each track is written with only the changed fields it can hold, against itself as read
   (`FR-TE-07`), with a count of the progress.
6. The form closes, the screen says how many songs were saved, and the library updates without a scan (`FR-TE-08`).

Alternative flows:

| ID | Condition | Outcome |
| --- | --- | --- |
| AF-01 | Some tracks are not MP3 or FLAC, or cannot be changed safely | They are named before saving and left alone (`FR-TE-06`). |
| AF-02 | No track can be changed | The form says why and offers nothing to save. |
| AF-03 | The album or artist has one track | The one-track form opens (UC-35). |
| AF-04 | The owner changes nothing, or a number is not valid | *Save* stays unavailable. |
| AF-05 | A track has no track or disc number and the owner sets its total | That track keeps its total and is noted; its other changes are written. |
| AF-06 | Some tracks cannot be written | The others stay written; each failed track is named with its reason, and those in use, failed or changed since read can be tried again (`FR-TE-08`). |
| AF-07 | On Android, permission to change audio files is refused | As UC-34 AF-08; nothing is written. |
| AF-08 | The owner cancels before saving | Nothing is written. |

## 9. Left to the builder

Exact string wording and key names; widget structure inside the dialog; whether `ManyTagEditState` holds the files or
the controller does; the file order (library order is fine); how the skipped list expands; rebasing over
`feature/genres` when it lands in develop (it changes `_GroupActions` in `music_rows.dart` to play within a
`MusicScope`, and adds UC-36 and CHANGELOG lines).
