# Edit a track's tags by hand — design

Status: draft for review · 2026-10-13 · branch `feature/edit-tags` · issue
[artur-rios/orpheus#53](https://github.com/artur-rios/orpheus/issues/53)

## 1. Intent

The owner fixes a track's tags themselves, from the track's own menu, when autofill has nothing to offer — MusicBrainz
does not know the recording, matches the wrong one, or the owner simply knows better.

- **Edit tags…** sits in the same menu the three-dots button, a right-click and a long press all open.
- It opens a form holding what the **file itself** says, every field the autofill can write — title, artist, album
  artist, album, track no./total, disc no./total, year, genre — and the front **cover**.
- Only fields the owner actually changed are written, through the same writer, the same safeguards and the same rescan
  as an autofill.

Success: a misspelt title, a missing track number or a wrong cover on one track is fixed in a few seconds without
leaving Orpheus, the library and every screen show the fix without the owner starting a scan, and nothing the owner did
not change is touched.

Decisions taken during brainstorming:

| Question | Decision |
| --- | --- |
| Scope | One track at a time, from its menu. Editing a whole record's shared fields at once is out. |
| Fields | Everything the writer writes: the ten text and number fields of `AutofillField`, and the cover. |
| Cover | Pick a JPEG or PNG from disk, or remove the embedded front cover. |
| Form | One adaptive dialog — a dialog on a wide window, full screen on a narrow one (approach 1). |
| Formats | MP3 and FLAC, as for autofill (`FR-AF-05`). Every other format is told it cannot be changed. |

## 2. Product and documentation changes

Autofill already rewrote the promise that files are never written; this feature adds a second, owner-typed source of
the changes, so the documents name it beside autofill. All in the same pull request.

- **Vision Document**
  - §1.2 Scope: "not a tag editor" is dropped — it now edits one track's tags by hand. It remains not a library
    manager (no renaming, moving or batch editing).
  - **F-18 Edit a track's tags** — new feature row.
  - **C-03** — "only for changes the owner has confirmed (`FR-AF-05`)" gains `FR-TE-03`; a manual edit is a confirmed
    change by construction (the owner pressed *Save* on what they typed).
- **System Requirements Document** — new `FR-TE-*` section:
  - **FR-TE-01** The owner must be able to edit, from a single track's menu, its title, artist, album artist, album,
    track number and total, disc number and total, year, genre and front cover, starting from what the file holds.
  - **FR-TE-02** A field the file's format cannot hold must be shown as not editable, and a file Orpheus cannot write
    must say so and offer nothing to save.
  - **FR-TE-03** Only fields the owner changed may be written, through the same writer and under the same rules as
    `FR-AF-05`; a cleared field removes the tag.
  - **FR-TE-04** A saved edit must reach the library and every screen without the owner starting a scan, and a file
    that could not be written must be named with the reason (as `FR-AF-07`), keeping the owner's edits.
  - **FR-AF-08** and **NFR-03** widen from "an autofill the owner confirmed" to "an autofill or a tag edit the owner
    confirmed". Feature traceability gains `F-18 → FR-TE-01 … FR-TE-04`.
- **Use Case Specification** — new **UC-35: Edit a track's tags by hand** (main flow and alternative flows of §6), and
  its row in the traceability table.
- **README** and **docs site overview** — a bullet beside *Fills in tags from MusicBrainz*; *It changes your files only
  when you ask* names the manual edit beside the autofill; the Android section says write access is used for an
  autofill or a tag edit.
- **CHANGELOG** — `### Added` under `[Unreleased]`.

No permission, manifest or CI change: the write path, and its Android access request, are the autofill's.

## 3. Architecture

A new feature folder, `lib/features/tag_editor/`, laid out like the others. It depends on the autofill feature's
`TagWriter`, `FileTags`, `AutofillField` and `WriteOutcome` rather than copying them — they describe tag writing, not
MusicBrainz, and renaming them is churn this change does not need.

```
lib/features/tag_editor/
  domain/tag_edits.dart            pure: what the form changed, and number/cover validation
  domain/cover_picker.dart         interface: ask the owner for an image file's bytes
  data/file_picker_cover_picker.dart   CoverPicker over file_picker
  application/tag_edit_controller.dart load → edit → save, per track
  presentation/edit_tags_dialog.dart   the form
  presentation/edit_tags_launcher.dart startTagEdit(context, ref, entry)
```

`coverPickerProvider` is added to `core/di/providers.dart`, beside `folderPickerProvider`, for the same reason: a native
dialog cannot be opened in a widget test.

### 3.1 Domain — `tag_edits.dart`

```dart
/// What the owner typed or picked, field by field.
class TagForm {
  final Map<AutofillField, String> text;   // as typed, untrimmed
  final CoverChoice cover;                 // keep | remove | replace(bytes)
}

/// The fields [form] changes against [before]; empty when nothing changed.
Map<AutofillField, Object?> tagEdits(FileTags before, TagForm form);

/// Why [text] is not a valid value for the number [field], or null.
NumberProblem? numberProblem(AutofillField field, String text);

/// Whether [bytes] are a JPEG or a PNG, by their first bytes.
bool isSupportedCover(Uint8List bytes);
```

Rules, each a unit test:

- A field is compared as the form shows it: the starting text is `before.values[field]` rendered as text
  (`shownAsOne` already joined several values as `Rock; Pop`, `3; 4`). Text equal to that, after trimming, is **no
  change** — so a field held several times and left alone is not rewritten.
- A text field trimmed to empty is `null` (removes the tag); otherwise the trimmed string.
- A number field trimmed to empty is `null`; otherwise it must parse as a whole number ≥ 1 (year: 1 … 9999). An invalid
  number is a `NumberProblem`, and `tagEdits` is only called once there are none.
- A field not in `before.writable` is never in the result.
- Cover: `keep` → absent; `remove` → `null`, only if the file has a cover; `replace(bytes)` → the bytes, unless equal
  to the current cover.

### 3.2 Application — `TagEditController`

An auto-disposed `Notifier<TagEditState>`, started with `load(MusicEntry entry)` by the dialog.

```
loading ──inspect──▶ editing ──save──▶ saving ──written──▶ saved
              │                 ▲          │
              └─ unwritable     └──────────┴─ anything else: editing + outcome
```

- `load`: `tagWriter.inspect(path)`; `canWriteTagsTo(path)` false or `writable` empty → `unwritable` (with which of the
  two, for the message).
- `save(edits)`: one at a time (a second tap is ignored while saving).
  1. `libraryAccessController.ensureWritable()`; refused → back to `editing` with the refusal.
  2. `tagWriter.write(path, edits, expected: entry.file)`.
  3. `written` → `rescanSoon()`, state `saved`. Anything else → `editing` with the outcome; the form is untouched.
- `reload()`: after `changedSinceRead`, inspects again and replaces the starting values.

As in the autofill, the writer and the scan controller are read before the first await, so a write the owner confirmed
still finishes and is still followed by a rescan if the dialog closes mid-save.

### 3.3 Presentation

**Menu.** `MusicRowMenu` gains *Edit tags…* (`Icons.edit_outlined`) directly after *Autofill tags…*, calling
`startTagEdit(context, ref, entry)`. One menu, so the three-dots button, right-click and long press all reach it.

**Dialog.** `EditTagsDialog`, shown with `showDialog`; below 600 logical pixels wide it is `Dialog.fullscreen`,
otherwise a dialog about 480 wide, scrolling.

- Title: *Edit tags*, and the track's display name beneath.
- Loading: a progress indicator.
- Unwritable: `autofillNothingWritable` or `autofillUnsafeTags`, and *Close*.
- Editing: the cover first — thumbnail (or a placeholder), *Choose image…* and *Remove* — then title, artist, album
  artist, album, then track no./total and disc no./total in pairs, year, genre. Number fields use a number keyboard and
  show *Enter a whole number* (or the year's range) under an invalid value. Fields not writable are disabled, with
  `autofillNotWritableFields` naming them once under the form.
- A picked file that is not JPEG or PNG leaves the cover as it was and says *Choose a JPEG or PNG image*.
- Actions: *Cancel* and *Save*. *Save* is enabled only with at least one change and no invalid number; while saving it
  shows a progress indicator and the form is read-only.
- After a failed save: the outcome's existing message (`autofillOutcomeChanged`, `…InUse`, `…Denied`, `…Failed`,
  `…Unsupported`) above the actions; *Save* reads *Try again* for in-use and failed; changed-since-read offers *Reload*.
  A refused Android access shows the autofill's refusal text and, where permanent, the settings action.
- On `saved` the dialog closes and the launcher shows a snackbar, *Tags saved*.

**Strings.** Field labels and outcome messages reuse the `autofill*` keys. New keys, in `app_en.arb` and `app_pt.arb`:
`tagEditAction`, `tagEditTitle`, `tagEditSave`, `tagEditChooseCover`, `tagEditRemoveCover`, `tagEditNoCover`,
`tagEditCoverNotImage`, `tagEditWholeNumber`, `tagEditYearRange`, `tagEditReload`, `tagEditSaved`.

## 4. Data flow

```
menu ─▶ startTagEdit ─▶ EditTagsDialog ─▶ TagEditController.load ─▶ TagWriter.inspect(path)
                                   │
                         owner edits │ TagForm
                                   ▼
            tagEdits(before, form) ─▶ TagEditController.save
                                          ├─ ensureWritable (Android)
                                          ├─ TagWriter.write(path, edits, expected: entry.file)
                                          └─ written ─▶ ScanController.rescanSoon ─▶ catalog ─▶ every screen
```

## 5. Error handling

Every failure is one the autofill already names; the editor keeps the owner's typing through all of them.

| Case | What the owner sees |
| --- | --- |
| Not MP3/FLAC | *Orpheus can only change the tags of MP3 and FLAC files.* — nothing to save. |
| MP3/FLAC whose tags cannot be changed safely | The autofill's *can't safely change* message — nothing to save. |
| Field the format cannot hold | Disabled, named under the form. |
| Invalid number | Inline under the field; *Save* disabled. |
| Picked file is not JPEG/PNG | Cover unchanged; inline message. |
| File changed by another program since read | Reason, and *Reload*. |
| File in use (Windows, the track playing) | Reason, and *Try again*. |
| Denied / failed | Reason; *Try again* for failed. |
| Android write access refused | Nothing written; the refusal and, if permanent, the settings action. |
| `inspect` throws | Treated as unwritable (`autofillUnsafeTags`), logged. |

## 6. UC-35 alternative flows (for the Use Case Specification)

| ID | Condition | Outcome |
| --- | --- | --- |
| AF-01 | The file is not MP3 or FLAC, or its tags cannot be changed safely | The dialog says so and offers nothing to save. |
| AF-02 | The format cannot hold a field | That field is shown and not editable. |
| AF-03 | The owner changes nothing, or a number is not a whole number | *Save* stays disabled. |
| AF-04 | The owner picks a file that is not a JPEG or PNG | The cover is unchanged and the dialog says why. |
| AF-05 | The file cannot be written | As UC-34 AF-07, for one file; the edits stay in the form. |
| AF-06 | On Android, write access is refused | As UC-34 AF-08; nothing is written. |
| AF-07 | The owner cancels | Nothing is written. |

## 7. Testing

- `test/features/tag_editor/domain/tag_edits_test.dart` — every rule in §3.1: unchanged, trimmed, cleared, several
  values left alone and edited, not writable, numbers valid/invalid/zero/negative/year bounds, cover keep/remove/
  replace/same bytes, JPEG/PNG/other detection.
- `test/features/tag_editor/application/tag_edit_controller_test.dart` — with a fake `TagWriter` and scan controller:
  unwritable by extension and by empty `writable`; inspect throwing; save written → `saved` and one `rescanSoon`;
  each other outcome → `editing` with it and no rescan; refused access → nothing written; second save ignored while
  saving; reload replaces the starting values.
- `test/features/tag_editor/presentation/edit_tags_dialog_test.dart` — fields prefilled; *Save* disabled until a change;
  invalid number blocks *Save*; non-writable field disabled; remove cover; a fake `CoverPicker` returning a PNG and a
  GIF; unwritable message; failed outcome keeps typed text; saved closes with *Tags saved*.
- `music_rows` widget test — the menu, opened by the three-dots button and by right-click, holds *Edit tags…*.
- The project's verification: `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`.

## 8. Out of scope

Editing several tracks or a whole record at once; tags beyond the eleven `AutofillField`s (composer, comment, lyrics);
writing any format other than MP3 and FLAC; resizing or recompressing a picked cover.
