# Auto playlists — design

Status: draft for review · 2026-10-18 · branch `feature/auto-playlists` · use case UC-40

## 1. Intent

Step 5 of the owner's library work. Two playlists Orpheus keeps by itself from what the owner listens to —
**Favourites lately** and **All-time favourites** — shown in an *Auto playlists* section of the Playlists tab (step 4),
and hidden by a preference. Step 6 (export all the owner's data to JSON) follows.

Success: after a few weeks of listening, *Favourites lately* holds what the owner has had on repeat this month and
*All-time favourites* what they always come back to; both play, shuffle and export like any playlist; turning them off
in Preferences hides them; and nothing about the statistics screen, or the owner's existing play history, is lost.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| Where | An *Auto playlists* section at the top of the Playlists tab, above the owner's own playlists. |
| Which | *Favourites lately* and *All-time favourites*. |
| Setting | *Show auto playlists* in Preferences, on by default. Off only hides them; the history keeps recording. |
| "Lately" | Option B: from now on, record the date of every play; "lately" counts plays in the last 30 days. Until there is enough recent history it falls back to option A (played in the last 30 days, ranked by total plays). |
| Existing history | Carried over to the new history format, counts and last-played kept — never reset. |
| Sizes | 50 songs each. Lately: the last 30 days. Fallback until at least 10 songs have recent plays recorded. |
| Order | Most plays first; ties go to the more recently played. |
| Missing songs | Songs not in the library are left out of both. |
| Updating | Both rebuild by themselves as the owner listens; no manual refresh. |
| What they allow | Open, *Play*, *Shuffle*, *Add to playlist…* (copy as a real playlist), *Export to .m3u…*, selection with *Edit tags…* and *Add to playlist…*. Not reorder, remove, rename, delete or a custom cover. Cover: the mosaic. |
| History size | Each song keeps the dates of its plays from the last 90 days only. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above; a history step 6 can export.
- **Non-goals:** more auto playlists (recently added, never played…); per-playlist settings (size, window); counting
  plays made before this version as dated plays.
- **Anti-goals:** the owner's play history is reset or shortened by the format change; the statistics screen shows
  different numbers than before for the same history; an auto playlist can be edited as if it were the owner's; an
  auto playlist written into `playlists.json`.

## 3. Behaviour

**The history, version 2.** `TrackPlays` gains `recent`: the play times within the last 90 days, newest last. Recording
a play adds its time to `recent`; **every write trims every track's `recent`** to the 90 days before the write, and a
read trims too, so stale dates never accumulate *(my call: the write already serialises the whole map)*. `plays` and
`lastPlayedAt` mean exactly what they meant. The JSON document becomes version 2 with `recent` (ISO-8601 UTC strings)
per track. **Reading a version-1 document migrates it**: every track kept with its `plays` and `lastPlayedAt`, `recent`
empty; it is written as version 2 on the next record. A document of an unknown (newer) version, or one that fails to
parse, follows the playlists rule — kept aside as `play-history.json.bad-<time>`, starting empty — instead of today's
start-over-and-overwrite *(my call: the owner's history is as precious as their playlists)*. If the
set-aside itself fails, the recorder keeps an empty history in memory and **writes nothing** until the next start —
plays are not recorded, playback is never interrupted, and the original file is never overwritten; it is logged. The statistics
(`music_stats.dart`) read only `plays` / `lastPlayedAt` and are unchanged.

**Favourites lately.** Let *recentCount(t)* = the number of `recent` times within the last 30 days (relative to now).
If at least 10 present songs have recentCount ≥ 1: the songs with recentCount ≥ 1, ordered by recentCount descending,
then `lastPlayedAt` descending, first 50. Otherwise (fallback): the songs whose `lastPlayedAt` is within the last 30
days, ordered by `plays` descending, then `lastPlayedAt` descending, first 50; the playlist shows a note *Getting to
know your recent listening* while the fallback is in use. When no song qualifies at all, only the empty state shows (*Play some
music and your recent favourites will show here*) — no fallback note.

**All-time favourites.** All present songs with `plays` ≥ 1, ordered by `plays` descending, then `lastPlayedAt`
descending, first 50. Empty → an empty state.

**"Present"** = in the current catalog (by path), and the catalog has loaded — as step 4's missing rule.

**Living lists.** The auto playlists are computed, never stored: from the play history, the catalog and the clock
(read at computation). They recompute when a play is recorded and when the catalog changes — no timer *(my call)*; the
30-day window moves on the next recompute. An open auto playlist may reorder under the owner as they listen; a
selection in it follows by path (step 3's pruning). The statistics screen keeps reading the history as it does today
(not live). Each has a fixed id (`auto:lately`,
`auto:all-time`) used for its open state and selection scope.

**Representation.** An auto playlist is shown as a `Playlist` value synthesised for display: id `auto:lately` /
`auto:all-time`, name localised, entry id = the song's path (no duplicates possible), snapshot from the catalog,
`modifiedAt` fixed. It is never written to `playlists.json`. Export takes the playlist value (not an id lookup), with
the localised name as the default file name (*Favourites lately.m3u*).

**In the tab.** The *Auto playlists* section is independent of the owner's playlists: it shows even when
`playlists.json` could not be read (above that error) or holds no playlists (then *Your playlists* shows an inline
empty state with *New playlist*, not the full-page one). While the catalog is loading the section shows a small
loading row; if the catalog failed, it is hidden. When the preference is on, the Playlists tab starts with an *Auto playlists* header and the two, as
rows or tiles like the owner's playlists, with cover (mosaic), name and *N songs*; then *Your playlists* and the rest as
in step 4. Their menu (⋮, right-click, touch and hold): *Add to playlist…* (all its songs), *Export to .m3u…*. When the
preference is off the section is not shown, and an open auto playlist closes.

**Inside an auto playlist.** The same view as a playlist (header, *Play*, *Shuffle*, rows), read-only: no drag
handles, no *Remove from playlist*, no rename/cover/delete; rows have the normal song menu; selection works (scope
`('playlist', 'auto:…')`, keyed by path — there are no duplicates) with *Add to playlist…* and *Edit tags…*. The
fallback note sits under the header. Back closes it as for a playlist.

**Preference.** *Show auto playlists* (on by default), persisted through `SettingsStore` like the other preferences,
in the Preferences dialog near the library options.

## 4. Architecture

- `lib/features/stats/domain/play_history.dart`: `TrackPlays.recent`, recording with the 90-day trim; version-2
  store with v1 migration and keep-aside (`json_play_history_store.dart`). `PlayRecorder` exposes the history as it
  changes so screens can react: e.g. a `playHistoryProvider` (`AsyncNotifier<PlayHistory>` or a stream) updated by
  each record — *builder's choice*, but the statistics screen and the auto playlists both read it.
- `lib/features/playlists/domain/auto_playlists.dart` (pure): `favouritesLately(history, catalogByPath, now)` and
  `allTimeFavourites(history, catalogByPath)` returning the ordered songs and whether the fallback applied.
- `autoPlaylistsProvider` (derived: history + catalog + clock + preference) → the two as read-only values the tab and
  the view render.
- `lib/features/playlists/presentation/`: the tab gains the section; `PlaylistView` / `PlaylistTrackList` gain a
  read-only mode (no handles, no remove) rather than a copy; `openPlaylistProvider` resolves `auto:` ids too.
- Preferences: a `showsAutoPlaylists` field on `PreferencesState` and its setting key, and its switch in
  `preferences_dialog.dart`.

## 5. Strings

New keys (both ARB files, descriptions): *Auto playlists*, *Your playlists*, *Favourites lately*, *All-time
favourites*, the fallback note, the two empty states, *Show auto playlists* and its description.

## 6. Documents

- **Vision:** **F-22 Auto playlists**.
- **SRS:** `FR-PS-14…` (the two lists and their rules, read-only, updating, preference), `FR-ST-*` (dated plays kept
  for 90 days, version-2 history with migration, unreadable history kept aside), traceability.
- **Use cases:** **UC-40: Play the auto playlists** (alternative flows: not enough recent history → fallback; empty;
  preference off; songs missing), and UC-28 (preferences) gains the switch.
- **Operations:** the data table notes the history's new version and the `.bad-` copy.
- README bullet + roadmap row + status line; docs site; CHANGELOG `Added` and `Changed` (history format, migrated).

## 7. Testing

- History: record adds a dated play and trims older than 90 days; v1 document migrates with counts kept and is written
  back as v2; garbage and newer versions kept aside; round trip; statistics unchanged for a migrated history (same
  numbers as before for the same v1 document).
- Auto playlists (pure): lately with enough recent plays (ordering, ties, 30-day window, 50 cap); fallback below 10
  songs (ordering, note flag); all-time (ordering, ties, cap); missing songs excluded; empty.
- Provider: updates after a play is recorded; respects the preference.
- Widgets: section shown/hidden by the preference; rows/tiles; open, Play, Shuffle; read-only (no handles, no remove,
  no rename/delete); selection *Add to playlist…* / *Edit tags…*; fallback note; empty states; menu *Add to playlist…*
  copies all songs; export; preference switch persists; turning it off closes an open auto playlist.
- `flutter analyze`, `flutter test`; new files `dart format`-clean.

## 8. Left to the builder

How the history change is published (provider vs stream); widget structure for the section; string key names
(`autoPlaylist…`); where the fallback note sits exactly.
