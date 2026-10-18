# Select several songs, and edit their tags — design

Status: draft for review · 2026-10-18 · branch `feature/select-songs` · use case UC-38

## 1. Intent

Step 3 of the owner's five library steps. The owner picks several songs in any song list and edits their tags at once —
"select them and have an edit option on mouse right click". Step 2 built the form over any list of tracks
(`startManyTagEdit`); this step adds the selection and opens that form over it. Step 4 (playlists) will add *Add to
playlist* to the same selection, so the selection is built as a general thing with one action today.

Success: on Windows, Ctrl-click four songs, right-click one of them, *Edit tags…*, change the genre, save — done; on the
phone, touch and hold one song, tap three more, *Edit tags…* in the bar. Playing music from a list works exactly as
before when nothing is selected.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| How to select | Both: touch and hold (phone) or Ctrl-click / Shift-click (desktop) starts a selection; tick boxes appear on every row only while selecting. |
| Touch and hold | Starts a selection instead of opening the song's menu; the menu stays on the row's ⋮ button. |
| Where | Every song list: Songs, inside an album, inside a genre, search results — they are all `MusicTrackList`. |
| While selecting | A tap or click on a row toggles it instead of playing it. Esc, ✕ or leaving the list ends the selection. |
| The bar | Replaces the top of the list: *N selected*, *Select all*, *Edit tags…*, ✕. *Edit tags…* is the only action for now. |
| Edit tags | Opens step 2's form over exactly the selected songs, labelled as selected songs; one selected song opens the one-track form. A save that wrote something clears the selection. |
| Right-click | On a selected song: a menu for the selection, *Edit tags…* first. On a song outside the selection: that song's own menu, as today. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above, in every song list, on phone and desktop; a selection step 4 can add actions to.
- **Non-goals:** selecting albums, artists or genres; drag-select or rubber-band selection; selecting across lists
  (the selection belongs to the list it was made in); actions other than *Edit tags…*; keyboard-only selection
  (arrow keys with Shift) beyond Esc.
- **Anti-goals:** a tap meant to play a song selects it, or a tap meant to select plays it; the selection silently
  holds songs the owner can no longer see; the album/artist rows lose their touch-and-hold menu (only song rows
  change).

## 3. Behaviour

**Starting.** Nothing is selected by default and the lists behave as today.

- Touch and hold a song row → selecting, with that song selected.
- Ctrl-click a song row (Windows, Linux; macOS is not a target) → selecting, with that song selected.
- A mouse long press counts as touch and hold. *(My call: harmless, and it is what `onLongPress` does.)*
- Shift-click a song row with nothing selected → selecting, with that song selected (it becomes the anchor).

**While selecting** (at least one song selected):

- Each row's leading slot (the track number inside an album, the cover elsewhere) shows a tick box instead. *(My call:
  in place of the number/cover rather than beside it, so a phone row does not lose title width.)*
- Tap / click a row, or its tick box → toggles that song. The row is not played.
- Ctrl-click → toggles. Shift-click → selects every song from the anchor (the last song toggled on) to this one, in the
  list's order, adding to the selection.
- Touch and hold → toggles.
- Deselecting the last song ends the selection.
- The ⋮ button still opens that song's own menu.

**The bar.** While selecting, a bar sits at the top of the list, above the rows (in the list's own area, so it works in
every host without changing the browser's header): ✕ (*Stop selecting*), *N selected*, *Select all* (selects every song
in the list; hidden or disabled when all are selected), *Edit tags…*.

**Right-click.** On a selected row: a menu for the selection holding *Edit tags…* (labelled with the count, e.g. *Edit
tags of 4 songs…*). On a row outside the selection: that song's own menu, unchanged.

**Ending.** ✕; Esc (desktop, while the list or anything in it has focus); Back (Android) — before Back does anything
else (clearing a search, going up a level); deselecting the last song; leaving the list (another destination, another
album, another search term); and after *Edit tags…* closes having written at least one song.

**The selection belongs to one list.** Each host gives its song list an identity — Songs; album *X* of artist *Y*;
Songs inside genre *G*; search for term *T* in field *F* — and the selection is made in, and only shown by, the list
with that identity. When the identity changes (another destination, another album, another genre, another search term
or field) the selection ends. *(My call: the same `MusicTrackList` element is reused when going from Songs into an
album or between albums, so "leaving" must be an explicit identity, not the widget being disposed.)*

Within the same identity it **follows the list**: it holds songs by file path, and when the list's songs change (a
rescan after a save) songs no longer in the list drop out; if none remain, it ends. While the library is reloading
and the list shows a spinner, the selection is kept (it lives in the provider, not the widget) and pruned once the
songs are back.

**The anchor** for Shift-click is the last song toggled, on or off. If it drops out of the list, there is none, and a
Shift-click then acts as a Ctrl-click.

**Edit tags.** *Edit tags…* (bar or menu) → `startManyTagEdit(context, selectedEntries, label: <"Selected songs">)`, the
entries in the list's order. One selected song opens the one-track form (the launcher already does this). The selection
stays while the form is open; it clears when the form closes with songs written, and stays otherwise (cancelled, or
nothing written) so the owner can adjust it.

## 4. Architecture

- **State:** a small, pure `SongSelection` value (selected paths, anchor) with the operations above — toggle,
  range-to, select all, retain-only (for "follows the list"), clear — in `lib/features/playback/domain/` beside the
  music layout types, unit-tested. *(Builder's choice where exactly; it has no Flutter.)*
- **Holder:** a Riverpod `Notifier` (auto-dispose not required) exposed from `core/di/providers.dart`, so the app's
  existing back handler in `lib/app.dart` can ask "is a selection open?" and clear it first — the one `PopScope` there
  decides what Back does, and a second `PopScope` inside the list would run alongside it, not before it.
- **List:** `MusicTrackList` reads and changes the selection, shows the bar and the tick boxes, routes taps, and prunes
  the selection to its entries (on build or on change). Leaving the list (it is disposed or shows another set of songs)
  ends the selection. Keyboard modifiers are read from `HardwareKeyboard.instance` at tap time.
- **Menus:** `MusicRowMenu` loses `onLongPressStart` (the list's long press selects instead). A **right-click** on a
  selected row while selecting opens the selection's menu instead of the song's; the row's **⋮ button always opens
  the song's own menu** (as agreed with the owner). `MusicGroupMenu` is unchanged.
- **Esc:** the list wraps its rows in a `Focus` with a `CallbackShortcuts` mapping Escape to clear; when a selection
  starts, that focus node requests focus (taking it from the search field is fine — the owner just clicked a row).
- **Identity:** `MusicTrackList` gains a required `selectionScope` (an `Object` compared with `==`, e.g. a record or a
  string built by the host); `MusicBrowser`'s two lists and `SearchResultsView` pass theirs. The selection stores the
  scope it was made in; a list whose scope differs neither shows nor keeps it.

## 5. Strings

New, in `app_en.arb` and `app_pt.arb` with descriptions: the count (*{count} selected*, plural), *Select all*, *Stop
selecting* (✕ tooltip), *Edit tags of {count} songs…* (menu item, plural), the form label *Selected songs*, and a
tick box semantic label (*Select {title}*). *Edit tags…* reuses `tagEditAction`.

## 6. Documents

- **Vision:** **F-20 Select several songs** — touch and hold or Ctrl/Shift-click in any song list, then edit their
  tags together.
- **SRS:** **FR-UX-11** A song list must let the owner select several songs — touch and hold, Ctrl-click and
  Shift-click start it; while selecting, a tap toggles a song instead of playing it, the selection's count and actions
  are shown, and Esc, Back or ✕ end it. **FR-UX-12** Touch and hold on a song starts a selection; the song's menu stays
  on its button. **FR-TE-09** The owner must be able to edit the tags of the selected songs as in `FR-TE-05` …
  `FR-TE-08`. Traceability `F-20 → FR-UX-11, FR-UX-12, FR-TE-09`. *(Builder: check FR-UX-01…10 for any rule about
  touch-and-hold opening the menu, and amend it.)*
- **Use cases:** **UC-38: Select several songs and edit their tags** (main flow: start selecting, add songs, *Edit
  tags…*, UC-37's form over them; alternative flows: one song → UC-35; Shift-click range; Back/Esc/✕ ends; leaving the
  list ends; right-click outside the selection opens that song's menu), traceability row, README roadmap row (no
  issue; link the use case), docs site overview, CHANGELOG `Added` (selection) and `Changed` (touch and hold on a song
  selects; its menu is on ⋮).

## 7. Testing

- Domain: toggle on/off, anchor moves, range forward and backward and adding to an existing selection, select all,
  retain-only dropping missing paths and ending when none remain, clear.
- Widget (`music_library_view_test.dart` or a new `music_track_list_test.dart`):
  - touch and hold starts selecting with that song; a tap then toggles and does not play
    (`FakeMediaPlayer`/player fake shows no play);
  - with nothing selected a tap still plays (regression);
  - Ctrl-click and Shift-click (via `tester.sendKeyDownEvent` around taps) select and range-select;
  - the bar shows the count; *Select all*; ✕ ends; Esc ends;
  - right-click a selected row → *Edit tags of N songs…* → `EditManyTagsDialog` over exactly those songs; right-click
    an unselected row while selecting → the song's own menu;
  - one selected song → `EditTagsDialog`;
  - after a save that wrote songs the selection is gone;
  - touch and hold on an album row still opens its menu (group rows unchanged).
- App: Back while selecting clears the selection and stays put (`app` or shell test where Back is already tested).
- `flutter analyze`, `flutter test`; new files `dart format`-clean.

## 8. Left to the builder

The bar's exact layout and widget; where `SongSelection` and its provider live; string key names (prefix
`musicSelection…`); how the list detects "leaving" (dispose vs a changed set of entries); the tick box's look.
