# Playlists — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Named playlists kept in Orpheus's own data — add songs, selections, albums and artists; play, shuffle,
reorder, remove, rename, delete; custom cover or mosaic; export to `.m3u` — in a new Playlists tab.

**Architecture:** A new `lib/features/playlists/` feature: a pure domain (model with entry snapshots, M3U text, mosaic
choice), a JSON store written atomically that never overwrites a document it cannot read, a per-playlist cover store,
a file-saver boundary over file_picker, an `AsyncNotifier` holding all playlists, and the tab, the playlist view and
the add-to-playlist picker. Entry points are added to the existing song, selection, album and artist menus.

**Tech Stack:** Flutter 3.47, Riverpod 3 (`Notifier`/`AsyncNotifier`), file_picker ^13.1.0, `flutter_test`, ARB (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-18-playlists-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; everything outward is a provider in
  `core/di/providers.dart`, overridden in `test/support/test_container.dart` / `Harness` so no test touches real files
  or dialogs.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`.
- Every new string in both `app_en.arb` and `app_pt.arb` with `@key` descriptions and the same placeholders; keys
  prefixed `playlist…`; `flutter gen-l10n`.
- No colour literals outside `lib/core/theme/`.
- Never write into the music folders. Playlists, their covers and nothing else go under the application-support
  directory (`appDirectoriesProvider`); `.m3u` export writes only the file the owner chose.
- A stored playlists document that fails to parse or has another version is kept aside as
  `playlists.json.bad-<timestamp>`, never overwritten.
- "Missing" is computed only once the catalog has loaded (`musicLibraryControllerProvider` is `AsyncData`).
- Selection inside a playlist is keyed by **entry id** in scope `('playlist', <playlist id>)`; elsewhere it stays as
  step 3 built it.
- Formatting: new files `dart format`-clean; edited files keep their surrounding style (never run the formatter
  tree-wide — the local Dart reflows ~80 unrelated committed files).
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A playlist is never lost:** a crash mid-write (atomic replace), an unreadable or newer document (kept aside), a
   rescan, an unreachable folder (entries kept, shown missing). (Task 2, Task 3.)
2. **The library still loading** never shows a playlist as all-missing or plays nothing. (Task 5
   `…WhileTheLibraryLoads…`.)
3. **The same song twice**: reorder, remove and tick act on one copy. (Task 1, Task 5.)
4. **Delete removes the playlist and its own cover only** — never a song, a file, or another playlist's cover.
   (Task 2, Task 3.)
5. **Every add path** (song, selection, album, artist) adds in the stated order and reports the count actually added,
   duplicates answered. (Task 6.)

---

### Task 1: The playlist domain

**Files:** create `lib/features/playlists/domain/playlist.dart`, `domain/m3u.dart`, `domain/playlist_mosaic.dart`;
tests under `test/features/playlists/domain/`.

**Produces:**
```dart
class PlaylistEntry {          // immutable, ==
  const PlaylistEntry({required this.id, required this.path, this.title, this.artist, this.album, this.duration});
  final String id, path; final String? title, artist, album; final Duration? duration;
  PlaylistEntry refreshedFrom(MusicEntry song); // same id/path, snapshot from the catalog
}
class Playlist {               // immutable, ==
  const Playlist({required this.id, required this.name, this.entries = const [], this.coverId, required this.createdAt, required this.modifiedAt});
  final String id, name; final List<PlaylistEntry> entries; final String? coverId; final DateTime createdAt, modifiedAt;
  Playlist renamed(String name, DateTime at);           // throws ArgumentError on blank; trims
  Playlist adding(List<PlaylistEntry> added, DateTime at);
  Playlist removing(Set<String> entryIds, DateTime at);
  Playlist moving(int from, int to, DateTime at);       // ReorderableListView semantics: `to` is the index before removal
  Playlist withCover(String? coverId, DateTime at);
  Set<String> pathsIn();                                // for the duplicate question
}
String? validPlaylistName(String text);                // trimmed, or null when blank
String playlistToM3u(Playlist playlist, Map<String, MusicEntry> catalogByPath); // #EXTM3U, #EXTINF:<secs|-1>,<artist> - <title>, path; \n line ends
List<String> mosaicCoverIds(Playlist playlist, Map<String, MusicEntry> catalogByPath); // ≤4, distinct albums, present songs only, playlist order
```
Ids are generated by the caller (Task 3); the domain never makes them.

- [ ] **Step 1: Write the failing tests**: `GivenAPlaylist_WhenSongsAreAdded_ThenTheyAreAtTheEndInOrder`;
  `GivenTheSameSongTwice_WhenOneCopyIsRemoved_ThenTheOtherStays`; `…WhenOneCopyIsMoved_ThenOnlyThatCopyMoves` (forward
  and backward with ReorderableListView's index rule); `GivenABlankName_WhenRenamed_ThenItIsRefused`;
  `GivenNamePaddedWithSpaces_WhenRenamed_ThenItIsTrimmed`; `…WithCover…` set and cleared; every operation bumps
  `modifiedAt`; M3U: header, EXTINF from the catalog when present and from the snapshot when missing, `-1` for an
  unknown duration, absolute paths, UTF-8 text with a non-ASCII title; mosaic: four distinct albums from six songs,
  one album → one id, missing songs skipped, no covers → empty.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: model playlists`.

---

### Task 2: Storing playlists, their covers, and saving a file

**Files:** create `lib/features/playlists/domain/playlist_store.dart`, `domain/playlist_cover_store.dart`,
`domain/file_saver.dart`, `data/json_playlist_store.dart`, `data/file_playlist_cover_store.dart`,
`data/file_picker_file_saver.dart`; modify `lib/core/di/providers.dart`, `test/support/` (fakes:
`FakePlaylistStore`, `FakePlaylistCoverStore`, `FakeFileSaver`, wired into `Harness` like the other fakes); tests
under `test/features/playlists/data/`.

**Produces:**
```dart
abstract interface class PlaylistStore { Future<List<Playlist>> read(); Future<void> write(List<Playlist> all); }
abstract interface class PlaylistCoverStore {   // one file per playlist id
  Future<void> put(String playlistId, Uint8List bytes); Future<Uint8List?> read(String playlistId); Future<void> delete(String playlistId);
}
abstract interface class FileSaver {            // null = the owner cancelled
  Future<String?> save({required String suggestedName, required Uint8List bytes});
}
final playlistStoreProvider, playlistCoverStoreProvider, fileSaverProvider; // in providers.dart
```
- `JsonPlaylistStore(directory)`: `playlists.json`, `{"version": 1, "playlists": [...]}` (schema documented in the
  class doc: ids, name, coverId, ISO-8601 times, entries with id/path/title/artist/album/durationMs). `write` encodes
  and calls `replaceFileAtomically` (lib/features/autofill/data/atomic_write.dart). `read`: no file → `[]`; a parse
  failure, a wrong shape or another version → rename the file to `playlists.json.bad-<yyyyMMddTHHmmss>` (clock from
  the caller or `DateTime.now`), log, return `[]`.
- `FilePlaylistCoverStore(directory)`: files `playlist-covers/<id>` (no extension needed; bytes are JPEG/PNG).
- `FilePickerFileSaver`: `FilePicker.platform.saveFile(fileName:, bytes:)` (file_picker writes the bytes on Android
  and iOS; on desktop it returns a path and the saver writes the bytes there).

- [ ] **Step 1: Write the failing tests** (real temp directories, as other `data/` tests do):
  `GivenPlaylists_WhenWrittenAndRead_ThenTheyRoundTrip` (snapshot fields, cover id, times, duplicates);
  `GivenNoFile_WhenRead_ThenThereAreNone`; `GivenGarbage_WhenRead_ThenItIsKeptAsideAndNoneAreLoaded` (the `.bad-`
  file holds the original bytes; `playlists.json` is gone); `GivenAnotherVersion_WhenRead_ThenItIsKeptAside`;
  `GivenAWriteThatFails_WhenWritten_ThenTheOldDocumentIsIntact` (e.g. a directory where the temp file should go, or
  however `atomic_write_test.dart` simulates a failure); cover store put/read/delete and two ids with the same bytes
  stay independent.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement**, providers rooted at `appDirectoriesProvider`'s support directory
  (see how `playHistoryStoreProvider` gets its directory). **Step 4: Run** — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: store playlists in the app's data`.

---

### Task 3: The playlists controller

**Files:** create `lib/features/playlists/application/playlists_controller.dart`,
`application/playlist_browse_controller.dart`; modify `providers.dart`; tests under
`test/features/playlists/application/`.

**Produces:**
```dart
final playlistsControllerProvider = AsyncNotifierProvider<PlaylistsController, List<Playlist>>(...);
class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  Future<Playlist> create(String name);                              // id from a generator provider (uuid-like; inject for tests)
  Future<int> add(String playlistId, List<MusicEntry> songs, {required bool skipDuplicates}); // returns count added
  Future<void> remove(String playlistId, Set<String> entryIds);
  Future<void> move(String playlistId, int from, int to);
  Future<void> rename(String playlistId, String name);
  Future<void> setCover(String playlistId, Uint8List bytes);         // cover store put + coverId = playlistId
  Future<void> removeCover(String playlistId);                       // cover store delete + coverId null
  Future<void> delete(String playlistId);                            // removes it and its cover, nothing else
  Future<String?> exportM3u(String playlistId);                      // FileSaver; returns the saved path or null if cancelled; throws on failure
}
final playlistBrowseProvider = NotifierProvider<PlaylistBrowseController, String?>(...); // open playlist id; open(id), close()
```
Every mutation writes the whole list through `PlaylistStore` and then updates `state`; mutations are serialised (one
at a time, queued — two quick adds must both land). Snapshots are taken from the `MusicEntry` at add time; when a
playlist is written, entries whose song is in the current catalog are `refreshedFrom` it. The clock and id generator
come from providers (`clockProvider`; add `idGeneratorProvider` if none exists).

- [ ] **Step 1: Write the failing tests** with the fakes: create persists; add appends in order and returns the
  count; `skipDuplicates` true skips paths already present (and duplicates within the batch are kept — the owner
  chose them); remove/move/rename persist; setCover/removeCover use the cover store; delete removes only that
  playlist and its cover (another playlist with the same picture keeps its file); two adds fired without awaiting
  both land; export passes the M3U bytes and suggested name `<name>.m3u` to the saver, returns null on cancel;
  browse open/close.
- [ ] **Step 2–4:** FAIL → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: create, change and delete playlists`.

---

### Task 4: The Playlists tab

**Files:** modify `lib/features/shell/domain/shell_destination.dart` (add `playlists` after `genres`),
`shell/presentation/shell_navigation.dart` (icons `Icons.playlist_play_outlined` / `Icons.playlist_play`, label),
`shell/presentation/shell_screen.dart` (`_Content`), `lib/app.dart` (Back: an open playlist closes to the list, after
the selection and search checks); create `lib/features/playlists/presentation/playlists_view.dart`,
`presentation/playlist_cover.dart`, `presentation/playlist_menu.dart`, `presentation/playlist_name_dialog.dart`;
strings; tests under `test/features/playlists/presentation/` and the shell tests.

Behaviour (spec §3 "The Playlists tab", "Rename / cover / delete", "Mosaic", "Export"): rows or tiles following the
shared `musicLayoutProvider` choice; most recently modified first; *New playlist* (name dialog, validation message on
blank); empty state; each row/tile has the playlist menu by ⋮, right-click and touch and hold: *Rename…*, *Choose
cover…* (existing `coverPickerProvider`, JPEG/PNG check `isSupportedCover`), *Remove cover* (only with a custom
cover), *Export to .m3u…* (snackbar *Saved to <path>* / *Couldn't export Road trip*), *Delete…* (confirmation naming the
playlist and saying the songs stay). `PlaylistCover(playlist, side)`: custom cover from the cover store, else a 2×2
mosaic of `AlbumArt`s from `mosaicCoverIds`, one → single, none → placeholder icon. Tapping a playlist opens it
(`playlistBrowseProvider.open`) — Task 5 builds what opens; until then show its name and an empty body.

- [ ] **Step 1: Write the failing tests:** the shell has five destinations and Playlists shows `PlaylistsView`;
  empty state; *New playlist* creates and lists it; blank name refused; rows and tiles; most recent first; rename;
  choose cover (FakeCoverPicker PNG) shows it, a GIF is refused; remove cover returns to the mosaic; mosaic of four;
  export → saver called, snackbar; export cancelled → nothing said; delete asks and removes; Back with a playlist open
  closes it.
- [ ] **Step 2–4:** FAIL → strings + `flutter gen-l10n` → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: list playlists in their own tab`.

---

### Task 5: Inside a playlist

**Files:** create `lib/features/playlists/presentation/playlist_view.dart`,
`presentation/playlist_track_list.dart`; modify `lib/features/playback/presentation/music_rows.dart` only to extract
what must be shared (the selection bar and the song row's look) into widgets both lists use — no behaviour change
there; tests.

Behaviour (spec §3 "Inside a playlist", "Gestures in a playlist", "Reordering", "Playing"): header with
`PlaylistCover`, name, *N songs* and total length, *Play*, *Shuffle*, the playlist menu. Until the library has loaded,
a loading state. Rows: the song from the catalog when present, else the snapshot greyed with *Missing*; a drag handle
(`ReorderableListView` with `buildDefaultDragHandles: false` + `ReorderableDragStartListener` on the handle); tap
plays `playAll(name:, tracks:)` of present songs from that entry on (a missing entry: nothing); *Play* from the first
present, *Shuffle* all present shuffled; song menu with *Remove from playlist* (and the usual items). Selection keyed by
entry id in scope `('playlist', id)` via `songSelectionProvider`: touch and hold, Ctrl/Shift-click, tick boxes, the
bar with *Remove from playlist*, *Add to playlist…* (Task 6 wires it; leave the slot), *Edit tags…* (present songs,
duplicates collapsed, playlist order); dragging disabled while selecting; Esc/Back end it (Back already handles the
selection first).

- [ ] **Step 1: Write the failing tests:** rows in order with present and missing; `…WhileTheLibraryLoads_ThenItShowsLoadingNotMissing`;
  tap plays from that entry skipping missing; tapping a missing row plays nothing; Play / Shuffle; drag a handle
  reorders and persists; long press selects rather than drags; ticking one copy of a duplicated song ticks only it;
  bar *Remove from playlist* removes exactly the ticked entries; *Edit tags…* opens the many-track form over present
  songs once each; song menu *Remove from playlist*; Back from the open playlist returns to the list.
- [ ] **Step 2–4:** FAIL → implement → PASS (also `test/features/playback`, unchanged behaviour); analyze clean.
- [ ] **Step 5: Commit** `feat: play, reorder and edit a playlist`.

---

### Task 6: Add to playlist

**Files:** create `lib/features/playlists/presentation/add_to_playlist.dart`; modify
`lib/features/playback/presentation/music_rows.dart` (`MusicRowMenu`, the selection bar and selection menu,
`MusicGroupMenu` for albums and artists) and `playlist_view.dart` (the selection slot); tests.

**Produces:** `Future<void> startAddToPlaylist(BuildContext context, WidgetRef ref, List<MusicEntry> songs)` — no
songs → nothing; a dialog listing playlists (most recently modified first) with *New playlist…* first (name dialog,
then add to it); if any song's path is already in the chosen playlist, ask *Already in <name> — add again?* with *Add
anyway* / *Skip those* / Cancel; then `add`, and a snackbar *Added N songs to <name>* with the count actually added
(0 → *Nothing added*).

Entry points: song menu → `[entry]`; selection bar and selection right-click menu → the selected songs in list order;
album menu → `tracksOfAlbum(...)` gathered as `_gathered` already does for *Edit tags…*; artist menu →
`entriesOfArtist(...)` likewise; inside a playlist's selection → present ticked songs in playlist order.

- [ ] **Step 1: Write the failing tests:** each of the five entry points offers *Add to playlist…* and adds the right
  songs in the right order; *New playlist…* from the picker creates and adds; duplicates: add anyway / skip those /
  cancel; snackbar counts; an album of 3 adds 3 in track order; the selection bar still fits at 360dp in Portuguese
  (extend step 3's overflow test with the new action).
- [ ] **Step 2–4:** FAIL → strings → implement → PASS (also `test/features/playback`); analyze clean.
- [ ] **Step 5: Commit** `feat: add songs, albums and artists to playlists`.

---

### Task 7: Documents

**Files:** Vision, SRS, Use Case Specification, README, docs site overview, CHANGELOG — per spec §6: drop "playlists
that can be saved and named" from Vision §6 and add **F-21 Playlists**; SRS `FR-PS-01…` (create/rename/delete; add a
song, a selection, an album, an artist; reorder and remove; custom cover and mosaic; play and shuffle; missing entries
kept, shown and skipped; export to M3U; stored in application data, never in music folders, written atomically, an
unreadable or other-version document kept aside), **FR-UX-01** five destinations, **NFR-03** export writes only the
chosen file, traceability `F-21 → FR-PS-*`; **UC-39: Keep playlists** with alternative flows (duplicates, missing
files, library loading, unreadable store, export cancelled / failed, delete confirmation); README bullet, roadmap row
(no issue; link the use case) and status line `UC-01 to UC-39`; site overview row; CHANGELOG `[Unreleased]` `Added`.
Follow how step 3's docs commit did it (`git log --oneline --grep "describe selecting several songs"`).

- [ ] **Step 1:** write them. **Step 2: Commit** `docs: describe playlists`.

---

### Task 8: Verify and open the pull request

- [ ] `git fetch`; rebase onto `origin/develop` if it moved.
- [ ] `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; new files format-clean.
- [ ] Push `feature/playlists`; PR into `develop` titled `feat: playlists`, body as PR #60's (summary, testing, calls
  to check, a real-app check list), ending `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
