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

It is not a library manager, not a streaming client, not a tag editor, and not
a synchronisation service. It has no server and no account. It reaches a
network for exactly one thing — the words of a track that has none on the
machine — and the owner can turn that off.

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
| **Our product** | reads only what it was pointed at, never writes to an audio file, and reaches a network for one optional convenience and nothing else |

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
| **F-04** | Browsing | The library is browsed by artist, by record and by song, as rows or as a wall of sleeves, with a way back out of any level. |
| **F-05** | Search | Titles, artists and records are searched together, ranked so that a match at the start of a name outranks one in the middle. |
| **F-06** | Playback | A track, a record, an artist or the whole library shuffled can be played, with pause, seek, volume, and a queue that can be seen and jumped around in. |
| **F-07** | Repeat and resume | A queue or a single track can be repeated; a track interrupted part-way is offered again at the point it stopped. |
| **F-08** | Now playing | A persistent bar shows what is playing from anywhere in the application, and a full player shows the record's sleeve at the size of the window. |
| **F-09** | Resilient playback | A file that is missing or will not decode is named, stepped over, and the queue carries on; when nothing in a selection can be played, the application says so. |
| **F-10** | Background playback | On Android, playback continues once the application is no longer on screen, from a foreground service whose notification and lock screen carry the transport controls, and it yields correctly to phone calls and to headphones being unplugged. |
| **F-11** | Listening statistics | Plays are counted from the owner's own listening and presented as totals and four rankings — tracks, artists, records and genres. |
| **F-12** | Adaptive shell | The application arranges itself by window width: a rail on a desktop, a bar across the bottom on a phone, and the same rules between. |
| **F-13** | Preferences | Theme, language, volume, whether the player opens on play, and whether the library is re-scanned at launch — applied immediately and remembered. |
| **F-14** | Localization | English and Brazilian Portuguese, both catalogs complete. |
| **F-15** | Lyrics | Where the machine holds a track's words — a `.lrc` beside it, or the track's own tags — they are shown; where they carry times, the line being sung is lit, the sheet follows the music, and a line can be tapped to play from there. Nothing is fetched, guessed or written. |
| **F-16** | Sound bars | The player draws the spectrum of the recording being played, measured from its own samples with the engine that plays it, analysed once per track and kept. Until an analysis lands, and for a file that cannot be decoded, a deterministic stand-in is drawn in its place and named as one. |

## 5. Constraints

| ID | Constraint |
| --- | --- |
| **C-01** | Three targets — Windows, Linux, Android — from one source. No per-platform implementation of any feature above the platform edges. |
| **C-02** | No network access beyond the lyrics lookup (`FR-LY-13`), which the owner can turn off and which no playback depends on. Enforced by the shipped Android package declaring exactly the permissions its manifest lists and no others. |
| **C-03** | The owner's audio files are opened for reading only. |
| **C-04** | No server, no database, no account, no synchronisation. |
| **C-05** | Every flow above the platform edges must be testable without a real audio engine, a real device, or the developer's own filesystem. |
| **C-06** | Android 7 (API 24) is the minimum supported release. The engine would run on 23; three of the plugins will not, and the highest floor is the floor. |

## 6. Out of scope

Stated so that their absence is a decision rather than an omission: tag
editing, file renaming, moving or deletion, transcoding, streaming, scrobbling,
online metadata, cover-art or lyrics lookup, writing or re-timing lyrics back
into the owner's files, accounts, synchronisation, playlists that can be saved
and named, a media session on Windows or Linux, and time-windowed statistics.
