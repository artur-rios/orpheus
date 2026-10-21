# Vision Document — Orpheus

## 1. Introduction

### 1.1 Purpose

This document states what Orpheus is for, who it serves, and which features it
delivers. It is the top of the requirements chain: every `FR-<AREA>-xx` in the
[System Requirements Document](System%20Requirements%20Document.md) traces up to
an `F-xx` feature here, and every `UC-xx` in the
[Use Case Specification Document](Use%20Case%20Specification%20Document.md)
realises one or more of those requirements.

### 1.2 Scope

Orpheus is a single-owner music player for Windows, Linux and Android. It reads
audio files already present on the machine, derives a browsable library from
their tags, and plays them.

It is not a library manager, not a streaming client, and not a synchronisation
service. The one thing it changes in an audio file is its tags — by autofill,
a record at a time with every change confirmed or many songs at once with the
clear matches written once the owner has started it, or by hand for one track
or many at once — and only when the owner asks. The playlists the owner makes
are kept in its own data, never in the music folders. It has no server and no
account. It reaches a network for exactly one thing — the words of a track that
has none on the machine — and the owner can turn that off.

### 1.3 Definitions

| Term | Meaning |
| --- | --- |
| **Owner** | The single human user. There is no second role. |
| **Library folder** | A directory on disk the owner registered as a source of audio files. |
| **Catalog** | Everything a scan found: one entry per audio file, with its tags. |
| **Record** | An album, derived from the files sharing an album and album artist. |
| **Queue** | The tracks lined up to play, and the position within them. |
| **Media session** | The platform's own now-playing surface — notification, lock screen, and media buttons. |
| **Play** | One track heard past the threshold in `BR-19`. |
| **Sidecar** | A file beside a track, named after it, holding something about it — here, a `.lrc` of its words. |
| **Synced lyrics** | Words with a time against each line, so that the line being sung can be shown while it is sung. |
| **Spectrum** | How a moment of a recording divides across frequency bands — what the sound bars are drawn from. |
| **Stand-in** | The synthesised bars drawn for a track not yet analysed, or one that cannot be. Never presented as a measurement (`BR-35`). |

## 2. Positioning

### 2.1 Problem statement

| | |
| --- | --- |
| **The problem of** | having a music collection on disk and no good way to listen to it across the machines it is wanted on |
| **affects** | a person who owns files rather than subscriptions |
| **the impact of which is** | a choice between a streaming client that will not play their files and a desktop player that cannot leave the desk |
| **a successful solution would** | play their own files, unchanged, with one interface, on both their desktop and their phone, without an account, a server, or a network connection to play a note |

### 2.2 Product position

| | |
| --- | --- |
| **For** | a person with audio files on their own disks |
| **Who** | wants to browse and play them by what the tags say, on desktop and on a phone |
| **Orpheus is** | a local music player |
| **That** | reads registered folders, derives a library from their tags, and plays it with the same interface on Windows, Linux and Android |
| **Unlike** | a streaming client, which plays somebody else's catalog, or a desktop player, which stops at the edge of the desk |
| **Our product** | reads only what it was pointed at, writes to an audio file only to change its tags when the owner confirms each change, or starts a batch autofill knowing its clear matches are written without review, and reaches a network only for conveniences the owner starts or can turn off |

### 2.3 Relationship to Alexandria

Orpheus is the music half of Alexandria, taken out on its own. It shares
Alexandria's interface shape and its layering, and deliberately shares none of
its infrastructure: no Rust core, no FFI, no database, no session. That
separation is what makes an Android target possible, which is the reason the
project exists.

The two remain independent. Neither reads the other's data, and a change to one
is not a change to the other.

## 3. Stakeholders

| Stakeholder | Interest |
| --- | --- |
| **The owner** | Plays their music. The only user, and the only source of requirements. |
| **The maintainer** | Keeps three platform targets building from one source, and keeps the promises in `BR-02`, `BR-03` enforceable. |
| **The host platforms** | Windows, Linux and Android each impose rules the application must satisfy — permissions, background execution, window management — and each is a constraint rather than a stakeholder with wants. |

## 4. Features

Features are `F-xx`. Each is realised by requirements in the System
Requirements Document and demonstrated by use cases.

| ID | Feature | Description |
| --- | --- | --- |
| **F-01** | Library sources | The owner registers folders on disk as sources, is offered the platform's conventional music folder, and can unregister them. Nothing outside them is ever read. |
| **F-02** | Scanning and tag reading | Registered folders are walked, tags are read, cover art is extracted, and the result is kept as a catalog. Scans are incremental and report progress without blocking the interface. |
| **F-03** | Library derivation | Records and artists are derived from tags, with the album artist worked out across a record rather than per file, so half-tagged libraries browse sensibly. |
| **F-04** | Browsing | The library is browsed by artist, by record and by song, and by genre in a tab of its own — a record listed under every genre its tracks carry, and a genre played as only the tracks tagged with it — as rows or as a wall of sleeves, with a way back out of any level. |
| **F-05** | Search | Titles, artists, records and genres are searched together or one kind at a time, as a selector chooses — all, songs, artists, albums or genres — ranked so that a match at the start of a name outranks one in the middle. |
| **F-06** | Playback | A track, a record, an artist or the whole library shuffled can be played, with pause, seek, volume, and a queue that can be seen and jumped around in. |
| **F-07** | Repeat and resume | A queue or a single track can be repeated; a track interrupted part-way is offered again at the point it stopped. |
| **F-08** | Now playing | A persistent bar shows what is playing from anywhere in the application, and a full player shows the record's sleeve at the size of the window. |
| **F-09** | Resilient playback | A file that is missing or will not decode is named, stepped over, and the queue carries on; when nothing in a selection can be played, the application says so. |
| **F-10** | Background playback | On Android, playback continues once the application is no longer on screen, from a foreground service whose notification and lock screen carry the transport controls, and it yields correctly to phone calls and to headphones being unplugged. |
| **F-11** | Listening statistics | Plays are counted from the owner's own listening and presented as totals and four rankings — tracks, artists, records and genres; a track counts toward each of its genres. |
| **F-12** | Adaptive shell | The application arranges itself by window width: a rail on a desktop, a bar across the bottom on a phone, and the same rules between. |
| **F-13** | Preferences | Theme, language, volume, whether the player opens on play, and whether the library is re-scanned at launch — applied immediately and remembered. Preferences also offer exporting the owner's data, backing Orpheus up and restoring from a backup (F-23, F-24). |
| **F-14** | Localization | English and Brazilian Portuguese, both catalogs complete. |
| **F-15** | Lyrics | Where the machine holds a track's words — a `.lrc` beside it, or the track's own tags — they are shown; where they carry times, the line being sung is lit, the sheet follows the music, and a line can be tapped to play from there. Nothing is fetched, guessed or written. |
| **F-16** | Sound bars | The player draws the spectrum of the recording being played, measured from its own samples with the engine that plays it, analysed once per track and kept. Until an analysis lands, and for a file that cannot be decoded, a deterministic stand-in is drawn in its place and named as one. |
| **F-17** | Autofill tags | On a record, or on a single track, the owner chooses which tags to fill; Orpheus finds the release on MusicBrainz, shows every change file by file as the current value and the new one, and writes only the changes the owner leaves ticked — into the files and into the library. Only MP3 and FLAC can be written; every other format is read-only. The cover comes from the Cover Art Archive and is unticked until chosen. Many songs at once are F-25. |
| **F-18** | Edit a track's tags | From a track's menu, the owner edits its title, artist, album artist, album, track and disc numbers and totals, year, genre and front cover by hand, starting from what the file holds; only what they changed is written, into the file and into the library. Only MP3 and FLAC can be written. |
| **F-19** | Edit the tags of several tracks | From an album's or an artist's menu, the owner edits the artist, album artist, album, track total, disc number and total, year, genre and front cover of all its tracks in one form. A field the tracks disagree on is shown as mixed and left alone unless typed in; title and track number are not offered. Only what they changed is written, to each track that can hold it, into the file and into the library; the tracks that cannot be written are named. Only MP3 and FLAC can be written. |
| **F-20** | Select several songs | In any list of songs — all songs, inside an album or a genre, or search results — the owner touches and holds a song, or Ctrl-clicks or Shift-clicks one, to start a selection; tick boxes take the place of the track number or cover while it lasts, and a tap picks a song instead of playing it. A bar shows how many are selected, with *Select all*, a way out and *Edit tags…*, which opens the form of F-19 over exactly those songs. A song's own menu stays on its ⋮ button. Esc, Back or leaving the list ends the selection, and so does a save that wrote songs. |
| **F-21** | Playlists | The owner keeps named playlists. *Add to playlist…*, on a song, on a selection, or on an album or an artist, adds songs at the end of one the owner picks or of a new one, and asks before adding songs a playlist already holds. A Playlists tab lists them, most recently changed first, as rows or tiles; opening one shows its songs in the owner's order, with *Play* and *Shuffle*, and a drag handle on each song to reorder it. Songs can be removed one at a time or from a selection, and a playlist can be renamed, given a cover of the owner's own or the mosaic of up to four of its albums' covers, exported to an extended `.m3u` file the owner chooses, and deleted after asking, which never touches a song. A song whose file the library no longer has stays in the playlist, shown as missing and skipped when playing. Playlists are kept in Orpheus's own data, never in the music folders, and a stored document it cannot read is kept aside rather than written over. |
| **F-22** | Auto playlists | Orpheus keeps two playlists of its own from what the owner listens to, in an *Auto playlists* section at the top of the Playlists tab: *Favourites lately*, the songs played most in the last 30 days, and *All-time favourites*, the songs played most ever, up to 50 each, the more recently played first among equals. Until enough recent listening has been recorded, *Favourites lately* ranks the songs played in the last 30 days by their total plays and says it is getting to know the owner's listening. They are worked out as the owner listens, never stored, and a song the library no longer holds is left out. They open, play, shuffle, export to `.m3u`, and copy into a playlist of the owner's with *Add to playlist…*, but cannot be reordered, edited, renamed or deleted. A preference, on by default, hides them; the plays keep being recorded. To tell *lately* from *ever*, the play history keeps the date of every play of a song for 90 days; a history from an earlier version is carried over with every count and last-played date it held, never reset. |
| **F-23** | Export my data | The owner saves everything Orpheus knows about their music to one JSON file, from *Your data* in the preferences: *Export my data (JSON)…* asks where to save it, suggesting `orpheus-data-<yyyy-MM-dd>.json`. The file holds every song of the library with its path, tags and length, the artists and albums as they are listed, the owner's playlists with the details saved for each song, both auto playlists whatever the preference says, the play history — songs no longer in the library included — and the numbers of the statistics screen, with the version of the file's layout, the version of Orpheus and the time. The layout is documented in `docs/data-export.md` and versioned, so that the file serves for analysis in any tool or for another program to read, and so that Orpheus can restore the playlists and the play history from it (F-24); covers, audio and preferences are not in it. The export waits for the library, the playlists and the play history to load, never freezes the window, only reads the owner's data and writes the one file the owner chose, and says when a source could not be read — the section is then empty, the file says why, and the owner is told the export is partial. The backup that also holds the playlists' covers and the preferences is F-24. |
| **F-24** | Back up and restore | The owner moves Orpheus's state from one device to another, or recovers it after the data on a device was wiped. From *Your data* in the preferences, *Back up Orpheus (ZIP)…* saves one ZIP, suggesting `orpheus-backup-<yyyy-MM-dd>.zip`, holding the document of F-23, the cover picture of every playlist that has one and the preferences, music folders included; *About these exports* compares it with the JSON export, and each says in a line what it is for. *Restore from a backup…* reads such a ZIP or an exported JSON and refuses anything else, and a backup from a newer Orpheus, saying so. For a ZIP it first shows the music folders the backup names and this device's, so that the owner can point Orpheus at the music, taking the set chosen as the whole set, and scans the library, so that the backup's songs can be matched by path and then by tags and length. Then it shows what the file holds and offers, separately for the playlists, the play history and the preferences, *Merge*, *Skip* or *Replace*, each *Merge* to begin with, which never loses anything here; *Replace* says what it removes first. A part the backup could not read is not offered, so that a *Replace* cannot wipe real data with an empty section, and a part this device could not read is not written over. Each part is written whole or not at all, a part that fails does not stop the others, and a summary says what was restored and what was not. The music files are never touched, and the music folders change only through the first stage, which the owner confirms; the library itself is not restored but scanned again. |
| **F-25** | Autofill many songs at once | From an artist's, a genre's or a playlist's menu, from a selection of songs, or from the Music tab for the whole library (or, inside a genre, its songs), the owner chooses which tags to fill and starts an autofill of all those songs at once. Before anything is looked up, Orpheus says how many songs and records it covers, about how long it will take, that the matches it is sure of are written without asking and replace the tags they change, and how many songs cannot be changed; the owner confirms. It then looks the records up on MusicBrainz one after another, at the same pace as a single autofill, and writes a record at once only when the match is clear: an official release of the same title and artist whose every song has a track of the same title and, where the song numbers it, the same number; a song on its own, with no album, only when the recording has its title and artist and its length to within 3 seconds, and is filed under an official album that is not a compilation. Every other record is kept, unwritten, for the owner to check in the review of F-17, with the reason it is doubtful. The batch has its own screen with its progress and counts, can be left running while the rest of Orpheus is used, shows a small indicator in the app bar, and can be stopped, keeping what was written. At the end it says how many records were updated, which need the owner, and which were not found, could not be changed, could not be written or looked up, or were not reached, and why; files that were in use can be tried again. Only MP3 and FLAC are written; the batch is kept in memory only and is forgotten when Orpheus is closed. An album's own menu keeps the single, reviewed autofill of F-17. |

## 5. Constraints

| ID | Constraint |
| --- | --- |
| **C-01** | Three targets — Windows, Linux, Android — from one source. No per-platform implementation of any feature above the platform edges. |
| **C-02** | No network access beyond the lyrics lookup (`FR-LY-13`) and the update check, which the owner can turn off, and the MusicBrainz and Cover Art Archive lookups an autofill makes only when the owner starts one (`FR-AF-02`). No playback depends on any of them. Enforced by the shipped Android package declaring exactly the permissions its manifest lists and no others. |
| **C-03** | The owner's audio files are opened for reading, and written only to change their metadata — never renamed, moved, deleted or re-encoded — and only for changes the owner has confirmed — one by one, or, for a batch autofill, by starting it after being told that its clear matches are written without review (`FR-AF-05`, `FR-AF-09`, `FR-TE-03`). Only MP3 and FLAC are written, each by an editor that changes only what was asked for and keeps every other byte. |
| **C-04** | No server, no database, no account, no synchronisation. |
| **C-05** | Every flow above the platform edges must be testable without a real audio engine, a real device, or the developer's own filesystem. |
| **C-06** | Android 7 (API 24) is the minimum supported release. The engine would run on 23; three of the plugins will not, and the highest floor is the floor. |

## 6. Out of scope

Stated so that their absence is a decision rather than an omission: tag
editing beyond an autofill or a tag edit the owner confirms (`FR-AF`, `FR-TE`),
file renaming, moving or deletion, transcoding, streaming, scrobbling, any
lookup beyond the lyrics lookup, the update check and an autofill's MusicBrainz
and Cover Art Archive lookups, writing or re-timing lyrics back into the
owner's files, accounts, synchronisation, importing a playlist from a file,
importing the data or the backups of any other program (Orpheus restores only
its own backups and exports, F-24), identifying files by their sound, resuming
an autofill of many songs after Orpheus was closed, undoing a written change, a
media session on Windows or Linux, and time-windowed statistics.
