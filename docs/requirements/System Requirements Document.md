# System Requirements Document — Orpheus

## 1. Introduction

### 1.1 Purpose

The normative requirements. Functional requirements are `FR-<AREA>-xx`;
non-functional ones are `NFR-xx`. Platform and operational requirements are
`IR-xx` and live in the
[Operations & Infrastructure Document](Operations%20%26%20Infrastructure%20Document.md).

Every requirement here realises a feature from the
[Vision Document](Vision%20Document.md) and is demonstrated by at least one use
case in the
[Use Case Specification Document](Use%20Case%20Specification%20Document.md).
Section 4 is the traceability.

### 1.2 Areas

| Code | Area |
| --- | --- |
| `LB` | Library sources and scanning |
| `CT` | Catalog, browsing and search |
| `PL` | Playback |
| `BG` | Background playback and the media session |
| `ST` | Listening statistics |
| `UX` | Shell, preferences and presentation |
| `LY` | Lyrics |
| `VZ` | Visualisation |

### 1.3 Keywords

**Must** is normative. **Should** marks a requirement that may be traded away
against a stated conflict. **Never** is absolute and is enforced by a test
wherever a test can enforce it.

## 2. Functional requirements

### 2.1 Library sources and scanning (LB)

| ID | Requirement |
| --- | --- |
| **FR-LB-01** | The owner must be able to register one or more folders on disk as library sources, chosen through the platform's own folder picker. |
| **FR-LB-02** | The application must offer the platform's conventional music folder as a one-press registration, and must not register it without being asked. |
| **FR-LB-03** | A folder that does not exist, cannot be read, or is already registered must be refused, with the reason stated. |
| **FR-LB-04** | The owner must be able to unregister a folder. Unregistering must remove its files from the catalog and must never delete anything on disk (`BR-02`). |
| **FR-LB-05** | Registered folders must persist between runs. |
| **FR-LB-06** | The application must never read outside a registered folder (`BR-04`). |
| **FR-LB-07** | On a platform that gates reading the owner's audio files, the application must request that permission, and must request it only once a folder has been registered — never on a launch where nothing has been asked for. |
| **FR-LB-08** | A permission the owner refused permanently must be reported as such, with the system settings screen offered. |
| **FR-LB-09** | A scan must walk every registered folder, read the tags of every audio file found, and produce a catalog. |
| **FR-LB-10** | A scan must run without blocking the interface, and the library already on screen must stay usable while it runs. |
| **FR-LB-11** | A scan must report its progress. |
| **FR-LB-12** | A scan must be incremental: a file still present at the same size and modification time must be carried over rather than re-parsed (`BR-10`). |
| **FR-LB-13** | A file whose tags cannot be read must not stop the scan. It must be recorded and named to the owner (`BR-11`). |
| **FR-LB-14** | Cover art must be extracted at scan time and stored addressed by the hash of its bytes (`BR-12`). |
| **FR-LB-15** | A record with no embedded art but a cover image beside it on disk must use that image. |
| **FR-LB-16** | The catalog must be written atomically and read back at launch, so that a start is fast and an interrupted write cannot destroy the library. |
| **FR-LB-17** | A catalog written by an incompatible version must be discarded and re-scanned rather than partially read. |
| **FR-LB-18** | The owner must be able to start a scan on demand, and to have one run at launch, controlled by a preference. |

### 2.2 Catalog, browsing and search (CT)

| ID | Requirement |
| --- | --- |
| **FR-CT-01** | The library must be browsable by artist, by record and by song. |
| **FR-CT-02** | Records and artists must be derived from tags, never stored, with the album artist worked out across the record (`BR-08`, `BR-09`). |
| **FR-CT-03** | Drilling into an artist must show their records; drilling into a record must show its tracks in track order. |
| **FR-CT-04** | The owner must be able to return from any level to the one above it, and on Android the system back gesture must do so. |
| **FR-CT-05** | A listing must be presentable as rows or as a grid of sleeves, and the choice must persist. |
| **FR-CT-06** | Every track must be named by its tags and never by its file name (`BR-05`), with a single localized word standing in for each absent tag (`BR-06`). |
| **FR-CT-07** | Search must match titles, artists and records together. |
| **FR-CT-08** | Search results must be ranked so that a match at the start of a name outranks a match within it. |
| **FR-CT-09** | Search must be clearable, and clearing it must return the owner to the listing they were on. |
| **FR-CT-10** | A library with nothing in it must say so, and say what to do about it, rather than showing an empty list. |
| **FR-CT-11** | A record's sleeve must be decoded once per distinct picture and shared by every screen showing it. |

### 2.3 Playback (PL)

| ID | Requirement |
| --- | --- |
| **FR-PL-01** | The owner must be able to play a single track. |
| **FR-PL-02** | The owner must be able to play a record, starting at the track they chose, or shuffled. |
| **FR-PL-03** | The owner must be able to play everything by an artist, in order or shuffled. |
| **FR-PL-04** | The owner must be able to play the whole library shuffled, meaning every track the library holds and not the view currently shown. |
| **FR-PL-05** | The queue must be visible, in play order, and the owner must be able to jump to any entry in it. |
| **FR-PL-06** | The owner must be able to pause and resume, seek within the current track, and set the output volume; the volume must persist. |
| **FR-PL-07** | "Next" must move to the following track, and at the end of a queue set to repeat must return to its first. |
| **FR-PL-08** | "Previous" must restart the current track when playback is more than five seconds in, and step back otherwise (`BR-17`). |
| **FR-PL-09** | Repeat must cycle off → all → one, and must persist. |
| **FR-PL-10** | The position within a track must be recorded periodically while playing, immediately on pause, and immediately on seek. |
| **FR-PL-11** | Playing a single track that has a recorded position must offer the owner the choice of resuming or starting over, before anything opens (`BR-15`). |
| **FR-PL-12** | A record or an artist must never ask that question. |
| **FR-PL-13** | A track played to its end must leave no recorded position (`BR-16`). |
| **FR-PL-14** | A file that is missing or cannot be decoded must be named, stepped over, and the queue must carry on (`BR-14`). |
| **FR-PL-15** | When nothing in a selection could be played, the application must say so, and the notice must be dismissible. |
| **FR-PL-16** | A persistent playback bar must show what is playing from every area of the application. |
| **FR-PL-17** | A full player must be openable, showing the record's sleeve at the size the window allows, with the transport, the queue and the position. |
| **FR-PL-18** | Whether the full player opens itself when a track starts must be a preference. |
| **FR-PL-19** | The player must outlive the screen that started it (`BR-13`). |
| **FR-PL-20** | Two overlapping requests to open a track must not both advance the queue. |

### 2.4 Background playback and the media session (BG)

| ID | Requirement |
| --- | --- |
| **FR-BG-01** | On Android, playback must continue once the application is no longer on screen, by means of a foreground service. |
| **FR-BG-02** | The service must post a notification showing the track playing — its title, its artist, its record and its sleeve. |
| **FR-BG-03** | The notification and the lock screen must offer play, pause, next, previous and stop. |
| **FR-BG-04** | Media buttons on connected hardware must reach the player. |
| **FR-BG-05** | The permission to post the notification must be requested at the moment there is something to show, and a refusal must cost the notification and nothing else. |
| **FR-BG-06** | Playback must pause when the system takes the audio output away, and resume only where the system says the output has been handed back. |
| **FR-BG-07** | Playback must pause when headphones are disconnected, and must never resume by itself afterwards. |
| **FR-BG-08** | The media session must be a view of the player: it must hold no queue and decide nothing. |
| **FR-BG-09** | On a platform with no media session, the same seam must be bound to an implementation that shows nothing, so that no layer above it contains a platform check. |
| **FR-BG-10** | A media session that fails to start must be reported and stepped over; the application must still open and still play. |

### 2.5 Listening statistics (ST)

| ID | Requirement |
| --- | --- |
| **FR-ST-01** | A track must count as played once the owner has heard half of it or four minutes of it, whichever comes first (`BR-19`). |
| **FR-ST-02** | A track whose length the engine has not reported must count nothing (`BR-20`). |
| **FR-ST-03** | A play must be counted once per playthrough, and again for the next one (`BR-21`). |
| **FR-ST-04** | Recording a play must never interrupt playback, and a failure to record must be logged and dropped (`BR-22`). |
| **FR-ST-05** | Concurrent recordings must not lose plays. |
| **FR-ST-06** | The play history must persist between runs, written atomically. |
| **FR-ST-07** | A play history that cannot be read must start over rather than prevent the application from running. |
| **FR-ST-08** | The application must present the total number of plays and the number of distinct tracks they came from. |
| **FR-ST-09** | The application must present four rankings — most played tracks, artists, records and genres — read from the play history against the catalog (`BR-23`). |
| **FR-ST-10** | Every ranking must be drawn even when it is empty. |
| **FR-ST-11** | A played track whose tags name no artist, record or genre must be counted in the totals, excluded from those rankings, and the discrepancy must be explained on screen (`BR-24`). |
| **FR-ST-12** | A played file the catalog no longer holds must still count, and must be named by its file. |
| **FR-ST-13** | The statistics must be read once per opening and must not reorder themselves while being read; reading them again must be one action away. |
| **FR-ST-14** | The statistics screen must not fail because the library could not be read. |
| **FR-ST-15** | Before anything has been played, the screen must state what makes a track count. |

### 2.6 Shell, preferences and presentation (UX)

| ID | Requirement |
| --- | --- |
| **FR-UX-01** | The shell must present three destinations — music, queue, folders — and no more. |
| **FR-UX-02** | The destinations must be a rail where the window is wide enough and a bar across the bottom where it is not, decided by width at every size (`BR-28`). |
| **FR-UX-03** | The statistics screen must be reachable from the shell without becoming a fourth destination. |
| **FR-UX-04** | The owner must be able to choose light, dark, or the system's setting; the choice must persist. |
| **FR-UX-05** | The owner must be able to choose English, Brazilian Portuguese, or the system's language; the choice must persist. |
| **FR-UX-06** | A preference must apply immediately and be written behind; one that applied but could not be written must be reported (`BR-25`). |
| **FR-UX-07** | Every perceptible operation must present a loading state, and a failure must replace it with a message and a retry — never a spinner left running and never a silent dismissal. |
| **FR-UX-08** | Every colour must come from the theme's single seed, and no colour literal may exist outside the theme (`BR-26`). |
| **FR-UX-09** | Both language catalogs must stay complete, every message must carry a description, and a translation must use the same placeholders as its original (`BR-27`). |
| **FR-UX-10** | The desktop window's size and position must be restored between runs, and a minimum size enforced. |

### 2.7 Lyrics (LY)

Realises F-15.

| ID | Requirement |
| --- | --- |
| **FR-LY-01** | The application must show the words of the track playing, on demand, from the full player. |
| **FR-LY-02** | Words must be read from a `.lrc` file beside the track and named after it, from the track's ID3 `SYLT` frame, or from the track's lyrics text tag, and from no other source (`BR-29`). |
| **FR-LY-03** | Where more than one of those holds words, the sidecar must win, and the timed frame must win over the text tag (`BR-30`). |
| **FR-LY-04** | Words carrying a time per line must follow the music: the line being sung must be distinguished, and the sheet must bring it into view by itself. |
| **FR-LY-05** | Where the owner scrolls the words themselves, following must stop for long enough to read, and then resume. |
| **FR-LY-06** | Tapping a line that carries a time must move playback to that time. |
| **FR-LY-07** | Words carrying no times must be shown, must be stated to carry none, and must not follow the music. No time may be invented for them (`BR-31`). |
| **FR-LY-08** | A track this machine holds no words for must be told so plainly, together with where words would have to come from. It is not a failure state and must not be presented as one. |
| **FR-LY-09** | Reading the words must not block, interrupt or delay playback, and a file that cannot be read for them must cost the words and nothing else. |
| **FR-LY-10** | Nothing about the words may be written, cached beside the catalog, or saved back into the owner's files (`BR-32`). |
| **FR-LY-11** | A timed gap between verses must leave no line distinguished, rather than leaving the previous line lit through it. |
| **FR-LY-12** | The reader must accept the forms real files are written in: several times against one line, a `[offset:]` correction, per-word times, ID3v2.2 through v2.4, the four ID3 text encodings, and unsynchronisation. Times it cannot resolve must be declined rather than approximated (`BR-31`). |

### 2.8 Visualisation (VZ)

Realises F-16.

| ID | Requirement |
| --- | --- |
| **FR-VZ-01** | The full player must draw a visualiser that moves while a track plays and settles when playback stops. |
| **FR-VZ-02** | What it draws must be the spectrum of the recording being played, measured from that recording's own samples (`BR-33`). |
| **FR-VZ-03** | The measurement must use the playback engine as its decoder, so that whatever the application can play it can also analyse, on every target, with no second codec library. |
| **FR-VZ-04** | Analysis must run off the interface's isolate. It must never delay a track opening, interrupt playback, or hold up the screen (`BR-36`). |
| **FR-VZ-05** | A track must be analysed once. The result must be cached, keyed by the file's path, length and modification time, so that a file replaced at the same path is analysed again rather than drawn with the previous one's spectrum (`BR-34`). |
| **FR-VZ-06** | Until a track's analysis lands, and for any file that cannot be decoded, a stand-in must be drawn: deterministic for a given track and moment, and distinct between tracks (`BR-35`). |
| **FR-VZ-07** | The stand-in must never be presented as a measurement, and must be named as a stand-in wherever it is defined. |
| **FR-VZ-08** | A failure to cache an analysis must cost that track's cached analysis and nothing else; it must not be surfaced as an error and must not stop the bars from being drawn. |
| **FR-VZ-09** | The analysis cache must live apart from the cover cache and must be deletable on its own, costing only the work of building it again (`IR-05`). |
| **FR-VZ-10** | The visualiser must carry an accessible name, and where the system asks for reduced motion it must stop moving while the rest of the screen is unchanged (`NFR-12`). |
| **FR-VZ-11** | Scratch data written during an analysis must be deleted however the analysis ends, including where it fails or times out. |

## 3. Non-functional requirements

| ID | Requirement |
| --- | --- |
| **NFR-01** | **One source, three targets.** Windows, Linux and Android must build from the same source with no per-platform implementation of any feature above the platform edges. |
| **NFR-02** | **No network.** The application must make no network request of any kind. The Android package must declare no `INTERNET` permission, and this must be verifiable from the built package. |
| **NFR-03** | **Read-only on the owner's media.** No audio file may be written, renamed, moved or deleted. |
| **NFR-04** | **Startup is not gated on a scan.** The library from the last scan must be on screen before a new scan is started. |
| **NFR-05** | **Scanning is proportional to change.** Re-scanning an unchanged library must not re-parse it. |
| **NFR-06** | **The cover cache is proportional to records, not files.** |
| **NFR-07** | **Testability at the edges.** Every outward dependency must sit behind an interface bound in one composition root, and must be overridable in a test. |
| **NFR-08** | **No test may reach outside its process** — not to the developer's preferences, their application-support folder, their listening statistics, the native audio engine, a platform media service, or the network. |
| **NFR-09** | **A clean analyzer.** `flutter analyze` must pass with no issues and no known-warnings list. |
| **NFR-10** | **Every judgement is documented where it lives.** A rule that exists only in a document is a rule the next change will break. |
| **NFR-11** | **Failures are surfaced, never swallowed** — except where a documented rule says otherwise, as in `FR-ST-04`. |
| **NFR-12** | **Accessibility.** Interactive controls must carry labels, and the reduced-motion setting must be honoured. |

## 4. Traceability

### 4.1 Features to requirements

| Feature | Requirements |
| --- | --- |
| F-01 Library sources | FR-LB-01 … FR-LB-08 |
| F-02 Scanning and tag reading | FR-LB-09 … FR-LB-18 |
| F-03 Library derivation | FR-CT-02, FR-CT-06 |
| F-04 Browsing | FR-CT-01, FR-CT-03, FR-CT-04, FR-CT-05, FR-CT-10, FR-CT-11 |
| F-05 Search | FR-CT-07, FR-CT-08, FR-CT-09 |
| F-06 Playback | FR-PL-01 … FR-PL-07, FR-PL-20 |
| F-07 Repeat and resume | FR-PL-08 … FR-PL-13 |
| F-08 Now playing | FR-PL-16, FR-PL-17, FR-PL-18, FR-PL-19 |
| F-09 Resilient playback | FR-PL-14, FR-PL-15 |
| F-10 Background playback | FR-BG-01 … FR-BG-10 |
| F-11 Listening statistics | FR-ST-01 … FR-ST-15 |
| F-12 Adaptive shell | FR-UX-01, FR-UX-02, FR-UX-03, FR-UX-10 |
| F-13 Preferences | FR-UX-04, FR-UX-05, FR-UX-06, FR-PL-18, FR-LB-18 |
| F-14 Localization | FR-UX-09, FR-CT-06 |
| F-15 Lyrics | FR-LY-01 … FR-LY-12 |
| F-16 Sound bars | FR-VZ-01 … FR-VZ-11 |

### 4.2 Requirements to use cases

| Area | Use cases |
| --- | --- |
| LB | UC-01, UC-02, UC-03, UC-04, UC-05, UC-06 |
| CT | UC-07, UC-08, UC-09, UC-10, UC-11, UC-12 |
| PL | UC-13 … UC-23 |
| BG | UC-24, UC-25 |
| ST | UC-26, UC-27 |
| UX | UC-28, UC-29 |
| LY | UC-30, UC-31 |
| VZ | UC-32 |

## 5. Data model

Everything the application persists, and where.

| Document | Location | Contents |
| --- | --- | --- |
| **Catalog** | `catalog.json` in the application-support directory | One entry per audio file: path, size, modification time, and every tag read from it, plus the id of its cover. Written atomically; versioned. |
| **Play history** | `play-history.json`, beside the catalog | One entry per file ever played: path, play count, and when it last counted. Written atomically; versioned. |
| **Cover cache** | a `covers` directory | One file per distinct picture, named by the hash of its bytes. |
| **Analysis cache** | an `energy` directory | One file per analysed track — the measured spectrum, about a hundred kilobytes for a four-minute track — named by a key carrying the file's path, length and modification time. Disposable: deleting it costs a second per track and nothing else. |
| **Preferences** | the platform's own preference store | Library folders, theme, language, layout, volume, repeat mode, resume points, and the two behaviour switches. |

Lyrics are deliberately absent from this table. They are read from the owner's
own files each time the player asks for them and are never copied into this
application's directory — which is what keeps a corrected `.lrc` correct the
moment it is saved, with nothing to invalidate (`BR-32`).

Nothing else is written, and nothing is written outside these locations
(`BR-02`).
