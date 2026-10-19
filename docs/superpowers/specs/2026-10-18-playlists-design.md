# Playlists — design

Status: draft for review · 2026-10-18 · branch `feature/playlists` · use case UC-39

## 1. Intent

Step 4 of the owner's library work. The owner keeps named playlists inside Orpheus: they add a song, a selection of
songs, a whole album or a whole artist to one; they play it in their own order or shuffled; they reorder it, remove
songs, rename it, delete it, give it a cover of their own, and export it to `.m3u`. Step 5 (auto playlists) and step 6
(exporting all the owner's data to JSON, agreed during this talk) build on what this step stores.

Success: from any song, album or artist — or a selection — *Add to playlist…*, pick *Road trip* or make a new one, and
it is there in the Playlists tab, playable, in the order the owner arranged, with the cover they picked; it survives
restarts, rescans and a music folder that is briefly unreachable; exporting it gives a `.m3u` another player opens.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| Adding | *Add to playlist…* on a song's menu, on a selection (bar and right-click menu, beside *Edit tags…*), and on an album's and an artist's ⋮ menu. |
| Choosing | A dialog listing the playlists, *New playlist…* first. Songs are added at the end; a snackbar says *Added 12 songs to Road trip*. |
| Where they live | In Orpheus's own data, beside the catalog and the play history — never in the music folders. |
| Export | Each playlist can be exported to a `.m3u` file the owner chooses where to save. |
| The tab | A new **Playlists** destination beside Music, Genres, Queue and Folders: rows or tiles (the same layout switch as Albums) with cover, name and song count; *New playlist* at the top. |
| Cover | The owner's own picture if they chose one (copied into Orpheus's data); otherwise a mosaic of up to four album covers from the playlist. *Choose cover…* / *Remove cover* in the playlist's menu. |
| Inside a playlist | Its songs in the owner's order; *Play* and *Shuffle* at the top; tapping a song plays the playlist from there; drag handles reorder; *Remove from playlist* on each song's menu; selection (step 3) works here and its actions include removing. |
| Playlist menu | *Rename…*, *Choose cover…* / *Remove cover*, *Export to .m3u…*, *Delete…* (asks first; removes the playlist only, never songs or files). |
| Duplicates | Allowed. Adding songs some of which are already there asks *Already in Road trip — add again?* (*Add anyway* / *Skip those* / Cancel). |
| Missing files | A song whose file is no longer in the library stays in the playlist, greyed out as *missing*, and is skipped when playing — so an unplugged drive does not wipe a playlist. |

Separately agreed: **step 6** — export the owner's data (playlists, artists, albums, songs, statistics) to JSON —
comes after auto playlists. Out of this step.

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above, on Windows, Linux and Android; a stored model step 5 and step 6 can read.
- **Non-goals:** importing `.m3u`; smart/auto playlists (step 5); folders of playlists; syncing; sharing; playlists of
  albums as units (an album added is its tracks at that moment); following a moved file to its new path.
- **Anti-goals:** a playlist is lost or silently shortened (by a rescan, an unreachable folder, a corrupt write); a
  delete or remove touches an audio file; a tap meant to play a playlist song reorders or removes it; Orpheus writes
  anything into the music folders.

## 3. Behaviour

**Model.** A playlist has an id (stable, generated), a name (non-empty, trimmed; duplicates of another playlist's
name allowed — *My call*: names are labels, the id identifies), an ordered list of entries, an optional custom cover
id, and created / modified times. An entry is a song **file path** plus its own id (so the same song twice can be
reordered and removed one at a time), and a **snapshot** of the song's title, artist, album and duration taken when it
was added *(my call)*. While the song is in the library the row shows the catalog's current tags and the snapshot is
refreshed on the next write; when it is missing, the row and the `.m3u` use the snapshot. Steps 5 and 6 read this
schema.

**Adding.** The picker lists playlists by most recently modified, *New playlist…* first (asks the name, creates it,
adds to it). Songs are added at the end, in the order given: a song → itself; a selection → in its list's order; an
album → its tracks in track order (`tracksOfAlbum`, whole library, as step 2's menu gathers); an artist → their tracks
in artist order (`entriesOfArtist`). If any are already in the playlist: the duplicate question (above). Snackbar with
the count actually added.

**The Playlists tab.** Lists playlists (most recently modified first — *my call*; reorderable lists of playlists are a
non-goal), each with cover, name and *N songs*; an empty state with *New playlist*. Tapping opens it. Each row/tile has
the playlist menu (⋮, right-click, touch and hold — playlists are rows like albums, not song lists).

**Inside a playlist.** A header with the cover, name, count and total length; *Play*, *Shuffle*, the playlist's ⋮.
Rows: cover, title, artist, length, a drag handle (always shown; *my call* — no separate edit mode). Tapping a row
plays the playlist from that entry (`playAll(name:, tracks:)` from that point, missing entries skipped). Missing
entries are greyed, labelled *Missing*, not playable, and can be removed. Song menu as everywhere, plus *Remove from
playlist*. Selection (step 3's behaviour: touch and hold, Ctrl/Shift-click, tick boxes, the bar, Esc/Back) works here, but it is
keyed by **entry id**, not path, in the scope of that playlist — so ticking one copy of a song twice in the list ticks
that copy only *(my call)*. Missing rows can be ticked. The bar and right-click menu offer *Remove from playlist*
(removes exactly the ticked entries), *Add to playlist…* and *Edit tags…* (both over the ticked entries' present
songs, duplicates collapsed, in playlist order). Back goes up to the list of playlists.

**Gestures in a playlist.** The drag handle is the only drag target (no long-press drag); touch and hold starts a
selection as in every song list; tap plays from that entry (a missing entry does nothing); right-click and ⋮ as in
step 3.

**Reordering.** Dragging a handle moves that entry; saved at once. While a selection is active, dragging is disabled
(*my call*: two gestures on one row at once is a bug farm).

**Rename / cover / delete.** Rename asks for the new name (non-empty). *Choose cover…* uses the existing JPEG/PNG
picker; the bytes are copied into a playlist-covers store in Orpheus's data (not the library's cover cache, which a
rescan may clear). The store keeps **one file per playlist**, named by the playlist's id (not a content hash), so
two playlists with the same picture never share a file and deleting one never breaks the other *(my call)*; a
`PlaylistCover` widget draws the custom cover or the mosaic (`AlbumArt` stays the library's). *Remove cover* returns
to the mosaic. Delete asks *Delete Road trip? The songs stay in your library.*
and removes the playlist and its custom cover.

**Mosaic.** The covers (catalog `coverId`) of the first four distinct albums among the playlist's present songs, in a
2×2 grid; one album → its cover alone; none → a placeholder icon.

**Export to `.m3u`.** A save-file dialog (default name `<playlist name>.m3u`); writes an extended M3U, UTF-8:
`#EXTM3U`, then per present entry `#EXTINF:<seconds>,<artist> - <title>` and the file's absolute path. Missing
entries are written as their path too (another player can decide), *my call*. A failure to write says so in a
snackbar. On Android the dialog is the system's document picker.

**Durability.** Stored as one JSON document (`playlists.json`, versioned like `play-history.json`) in the
application-support directory; written atomically (write a temp file, rename — as the tag writer's atomic write); a
document that fails to parse, **or carries another version**, is kept aside as `playlists.json.bad-<timestamp>` and
the app starts with none, logging it (*my call*: never overwrite the owner's only copy of something we could not read;
`play-history.json`'s start-over rule is not followed here). Rescans never touch playlists;
"missing" is computed by looking each path up in the current catalog, and **only once the catalog
has loaded** — while it is loading the playlist view shows the loading state, never a wall of missing rows. A scan
that cannot reach a folder drops its tracks from the catalog, and they show as missing until it is reachable again —
which is the intended behaviour.

**Playing.** `playAll(name: playlist.name, tracks: present files from the tapped entry on)`; *Play* = from the first;
*Shuffle* = all present, shuffled. The queue's existing `QueueKind.playlist` labels it with the name.

## 4. Architecture

New feature folder `lib/features/playlists/`, laid out like the others:

```
domain/playlist.dart              Playlist, PlaylistEntry; pure operations: add, remove, move, rename, cover
domain/playlist_store.dart        interface: read all / write all
domain/m3u.dart                   pure: a playlist + catalog → .m3u text
domain/playlist_mosaic.dart       pure: the up-to-four cover ids
data/json_playlist_store.dart     JSON document, atomic write, keep-aside on parse failure
data/file_saver.dart              interface impl over file_picker's saveFile (desktop path; Android bytes)
application/playlists_controller.dart   AsyncNotifier<List<Playlist>>: create, add, remove, move, rename, set/remove cover, delete, export
presentation/playlists_view.dart  the tab: list/grid of playlists
presentation/playlist_view.dart   one playlist: header, rows, reorder
presentation/add_to_playlist.dart the picker dialog + startAddToPlaylist(context, ref, entries)
presentation/playlist_menu.dart   rename / cover / export / delete
```

- Providers in `core/di/providers.dart`: `playlistStoreProvider`, `playlistCoverStoreProvider` (a second
  `FileCoverStore` rooted in its own directory under application support), `fileSaverProvider`,
  `playlistsControllerProvider`, and a browse state for "which playlist is open" (like `GenreBrowseController`).
- Shell: `ShellDestination.playlists`, its icon and label, its place in navigation (after Genres — *my call*), and
  `app.dart`'s Back handler going from an open playlist to the list.
- Entry points: `MusicRowMenu` (*Add to playlist…*), the selection bar/menu (step 3's `_SelectionBar` and selection
  menu), `MusicGroupMenu` (album and artist). `startAddToPlaylist(context, ref, entries)` is the one launcher.
- Song rows inside a playlist reuse `MusicTrackList`'s row look and selection where it fits; if reorder and missing
  rows make `MusicTrackList` the wrong shape, a `PlaylistTrackList` sharing the row widget is the builder's call — the
  selection behaviour (step 3) must still apply there.

## 5. Strings

New `playlist…` keys in both ARB files with descriptions: tab label, New playlist, name prompt and its validation,
*N songs*, Add to playlist…, picker title, Added N songs to X (plural), duplicate question and its three answers,
Remove from playlist, Missing, Rename…, Choose cover…, Remove cover, Export to .m3u…, export saved / failed, Delete…,
the delete confirmation, empty states (no playlists; empty playlist), Play / Shuffle reuse existing keys where they
exist.

## 6. Documents

- **Vision:** drop "playlists that can be saved and named" from §6 Out of scope; **F-21 Playlists** feature row; the
  scope sentence mentions playlists kept in Orpheus's own data.
- **SRS:** a new `FR-PS-*` section — create/rename/delete; add a song, a selection, an album, an artist; reorder and
  remove; custom cover and mosaic; play and shuffle; missing entries kept and skipped; export to M3U; stored in
  application data, never in music folders, written atomically, an unreadable document kept aside. **FR-UX-01**
  becomes five destinations. **NFR-03** (files changed only for confirmed tags) gains: exporting writes only the file
  the owner chose. Traceability `F-21 → FR-PS-*`.
- **Use cases:** **UC-39: Keep playlists** (create, add, play, reorder/remove, rename, cover, export, delete; with
  alternative flows: duplicates, missing files, unreadable store, export failure, cancel).
- README feature bullet + roadmap row + status line; docs site overview; CHANGELOG `Added`.

## 7. Testing

- Domain: add/remove/move with duplicates, rename validation, cover set/remove, mosaic choice (distinct albums,
  missing skipped, fewer than four), M3U text (EXTINF, UTF-8, missing entries, durations unknown → `-1`).
- Store: round trip, atomic write leaves the old file on failure, unreadable document kept aside and none loaded,
  version mismatch.
- Controller: every operation persists; add with duplicates (add anyway / skip); delete removes the custom cover;
  export through a fake `FileSaver`.
- Widgets: the tab (empty, rows, tiles, New playlist); the picker (new, existing, duplicates question, snackbar);
  inside a playlist (play from a row, shuffle, missing row greyed and skipped, reorder by drag, remove, selection
  remove); menus on a song, a selection, an album and an artist offer *Add to playlist…*; rename, cover, delete
  confirmation; Back from a playlist to the list; the shell shows five destinations.
- `flutter analyze`, `flutter test`; new files `dart format`-clean.

## 8. Left to the builder

Widget structure; string key names; the exact JSON schema (versioned, documented in the store's doc comment); whether
the open-playlist state lives in a new controller or the shell's; the mosaic's drawing; the file-saver's handling of
each platform within file_picker's API.
