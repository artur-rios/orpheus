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
| `AF` | Autofill |
| `TE` | Tag editing |
| `PS` | Playlists |
| `DX` | Data export |
| `BK` | Backup and restore |

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
| **FR-CT-07** | Search must match titles, artists, records and genres, together or one kind at a time, as the owner chooses with a selector of *All*, *Songs*, *Artists*, *Albums* and *Genres*. A track matches a choice only through the fields that choice names, and the results stay a list of tracks. The choice must be kept while the application runs, and be *All* again at the next launch. |
| **FR-CT-08** | Search results must be ranked so that a match at the start of a name outranks a match within it, within each choice of `FR-CT-07`. |
| **FR-CT-09** | Search must be clearable, and clearing it must return the owner to the listing they were on. |
| **FR-CT-10** | A library with nothing in it must say so, and say what to do about it, rather than showing an empty list. |
| **FR-CT-11** | A record's sleeve must be decoded once per distinct picture and shared by every screen showing it. |
| **FR-CT-12** | The library must be browsable by genre, from a destination of its own in the shell: the genres listed, then inside one the artists, records and songs that carry it, as rows or as sleeves. The place the owner has reached there must be kept apart from the one in the music area, and be there when they return. |
| **FR-CT-13** | A record must be listed under every genre any of its tracks carries, and opening it from a genre must show the whole record, not only the tracks tagged with that genre (`BR-37`). An artist's tracks with no album name are not a record: under a genre they are listed as the artist's untitled group, holding only the tracks tagged with it (`BR-40`). |
| **FR-CT-14** | Playing a genre, or shuffling it, must queue only the tracks tagged with it. Inside a genre, playing an artist must queue that artist's records listed under the genre, whole, in the order shown, and playing a record or a track inside a record must play the whole record (`BR-38`). |
| **FR-CT-15** | A track with several genres must be listed under each of them. Every value a file holds must be kept, from every format that can hold several: a genre value is split at `;`, `\|` and `,` and never at `/`, a genre repeated on a track counts once, an MP3's ID3v2.4 genre frame keeps each of its values, and an ID3v1 numeric reference such as `(17)` is read as the genre it names (`BR-39`). A file holding several genre atoms in MP4 keeps only one. |
| **FR-CT-16** | Genres must be matched ignoring case and surrounding spaces, so `rock` and `Rock ` are one genre, shown in the spelling most tracks use — on a tie, the alphabetically first (`BR-39`). |
| **FR-CT-17** | Tracks with no genre must form a *No genre* group, listed after every genre and under the same rules: a record with any untagged track is listed there, and playing it plays only the untagged tracks (`BR-40`). A library with no genre tags at all must show only that group. |
| **FR-CT-18** | The owner must be able to return from any level of a genre to the one above it, and on Android the system back gesture must do so, after clearing a search. |
| **FR-CT-19** | A scan must not take the owner out of a record that has just lost the open genre's tag: it stays on screen, drawn whole from the library, and plays whole. A level left with nothing in it, or a genre that no longer exists, must be stepped out of. |

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
| **FR-ST-07** | A play history that cannot be read must not prevent the application from running. A file that is not understood is kept aside rather than written over, and the application starts with an empty history (`FR-ST-18`); a file that cannot be opened is left in place, and nothing is recorded in that run (`FR-ST-19`). |
| **FR-ST-08** | The application must present the total number of plays and the number of distinct tracks they came from. |
| **FR-ST-09** | The application must present four rankings — most played tracks, artists, records and genres — read from the play history against the catalog (`BR-23`). A track with several genres must credit each of them with its plays, and a genre's share of the plays must be of all plays, so shares may add up to more than 100%. |
| **FR-ST-10** | Every ranking must be drawn even when it is empty. |
| **FR-ST-11** | A played track whose tags name no artist, record or genre must be counted in the totals, excluded from those rankings, and the discrepancy must be explained on screen (`BR-24`). A track has no genre only when it has none at all. |
| **FR-ST-12** | A played file the catalog no longer holds must still count, and must be named by its file. |
| **FR-ST-13** | The statistics must be read once per opening and must not reorder themselves while being read; reading them again must be one action away. |
| **FR-ST-14** | The statistics screen must not fail because the library could not be read. |
| **FR-ST-15** | Before anything has been played, the screen must state what makes a track count. |
| **FR-ST-16** | Each play must be recorded with the date it was counted, beside the count and the last-played date. A track keeps the dates of its plays from the last 90 days only: every write, and every read, drops the dates older than that, so that they never accumulate. The count and the last-played date are not changed by it. |
| **FR-ST-17** | The play history must be a versioned document, now version 2, holding each track's dates. A version-1 document, as every earlier release wrote it, must be read with every track, its count and its last-played date kept and no dates, and be written as version 2 by the next play recorded. The first time one is read, its bytes must also be copied to `play-history.json.v1`, once and never over an earlier copy, so that, if an earlier release is installed, the history can be restored by hand from it (an earlier release does not read that copy). A history is migrated and never reset. |
| **FR-ST-18** | A document that cannot be understood — text that is not UTF-8 or not JSON, not a play history, or of a version this release does not read — must be kept aside under a name of its own, `play-history.json.bad-<time>`, and never overwritten; the application then starts with an empty history. A readable document holding a row that is not a play, or a date that is not one, must have that row or date stepped over, and the original document copied aside under the same kind of name before anything is written over it. |
| **FR-ST-19** | When the document can neither be read, nor kept aside or copied aside as `FR-ST-18` says, nor copied once to `play-history.json.v1` as `FR-ST-17` says, nothing may be recorded in that run: the history is held empty, nothing is written, and the document is never replaced. Playback is unaffected, the failure is logged, and the next start tries again (`FR-ST-04`). |
| **FR-ST-20** | The statistics (`FR-ST-08` … `FR-ST-15`) must read only the counts and last-played dates, so that a migrated history shows the same numbers as before for the same plays. |

### 2.6 Shell, preferences and presentation (UX)

| ID | Requirement |
| --- | --- |
| **FR-UX-01** | The shell must present five destinations — music, genres, playlists, queue, folders — and no more. |
| **FR-UX-02** | The destinations must be a rail where the window is wide enough and a bar across the bottom where it is not, decided by width at every size (`BR-28`). |
| **FR-UX-03** | The statistics screen must be reachable from the shell without becoming a sixth destination. |
| **FR-UX-04** | The owner must be able to choose light, dark, or the system's setting; the choice must persist. |
| **FR-UX-05** | The owner must be able to choose English, Brazilian Portuguese, or the system's language; the choice must persist. |
| **FR-UX-06** | A preference must apply immediately and be written behind; one that applied but could not be written must be reported (`BR-25`). |
| **FR-UX-07** | Every perceptible operation must present a loading state, and a failure must replace it with a message and a retry — never a spinner left running and never a silent dismissal. |
| **FR-UX-08** | Every colour must come from the theme's single seed, and no colour literal may exist outside the theme (`BR-26`). |
| **FR-UX-09** | Both language catalogs must stay complete, every message must carry a description, and a translation must use the same placeholders as its original (`BR-27`). |
| **FR-UX-10** | The desktop window's size and position must be restored between runs, and a minimum size enforced. |
| **FR-UX-11** | A list of songs — all songs, the songs of an album or of a genre, and search results — must let the owner select several of them. Touch and hold, Ctrl-click and Shift-click start a selection; while it lasts a tap toggles a song instead of playing it, the number selected and the actions that apply to them are shown, and Esc, Back, a control on screen, or leaving the list end it. |
| **FR-UX-12** | Touch and hold on a song must start a selection rather than open its menu; a song's menu stays on its ⋮ button and a right-click, which on a selected song opens a menu for the selection. Touch and hold on an album or an artist still opens its menu. |
| **FR-UX-13** | When a selection's bar is narrower than 480 logical pixels, *Edit tags…* in it must be an icon with a tooltip rather than a button with words, so that the count of what is selected keeps its room. The bar's other actions are icons with tooltips at any width. |

### 2.7 Lyrics (LY)

Realises F-15.

| ID | Requirement |
| --- | --- |
| **FR-LY-01** | The application must show the words of the track playing, on demand, from the full player. |
| **FR-LY-02** | Words must be read from a `.lrc` file beside the track and named after it, from the track's ID3 `SYLT` frame, or from the track's lyrics text tag. Whatever these hold is the answer, and no lookup may be made for a track they hold words for (`BR-29`). |
| **FR-LY-03** | Where more than one of those holds words, the sidecar must win, and the timed frame must win over the text tag (`BR-30`). |
| **FR-LY-04** | Words carrying a time per line must follow the music: the line being sung must be distinguished, and the sheet must bring it into view by itself. |
| **FR-LY-05** | Where the owner scrolls the words themselves, following must stop for long enough to read, and then resume. |
| **FR-LY-06** | Tapping a line that carries a time must move playback to that time. |
| **FR-LY-07** | Words carrying no times must be shown, must be stated to carry none, and must not follow the music. No time may be invented for them (`BR-31`). |
| **FR-LY-08** | A track this machine holds no words for must be told so plainly, together with where words would have to come from. It is not a failure state and must not be presented as one. |
| **FR-LY-09** | Reading the words must not block, interrupt or delay playback, and a file that cannot be read for them must cost the words and nothing else. |
| **FR-LY-10** | Nothing about the words may be cached beside the catalog or saved back into the owner's audio files. A sheet obtained by lookup must be written once as a new `.lrc` beside the track, never replacing an existing sidecar, and a refused write must cost the saving and nothing in the session (`BR-32`). |
| **FR-LY-13** | A track the machine holds no words for must be looked up against a lyrics service, and only such a track (`BR-29a`). |
| **FR-LY-14** | A lookup must send the track's artist and title, and its record and length where the tags give them, and nothing else — in particular no file name, no path, no account, no key and no identifier of any kind (`BR-29a`). |
| **FR-LY-15** | A track whose tags do not give both an artist and a title must not be looked up (`BR-29a`). |
| **FR-LY-16** | The lookup must be a preference the owner can turn off, stated where it is turned on in terms of what it sends and what it writes. Turning it off must not affect reading the owner's own files (`BR-29a`). |
| **FR-LY-17** | A lookup that finds nothing, is refused, or cannot be reached must leave the track stated to have no words, must not be presented as a failure, and must never block, interrupt or delay playback (`BR-29a`). |
| **FR-LY-11** | A timed gap between verses must leave no line distinguished, rather than leaving the previous line lit through it. |
| **FR-LY-12** | The reader must accept the forms real files are written in: several times against one line, a `[offset:]` correction, per-word times, ID3v2.2 through v2.4, the four ID3 text encodings, and unsynchronisation. Times it cannot resolve must be declined rather than approximated (`BR-31`). |

### 2.8 Autofill (AF)

Realises F-17 and F-25.

| ID | Requirement |
| --- | --- |
| **FR-AF-01** | The owner must be able to start an autofill on a record or on a single track, and choose which of title, artist, album artist, album, track number and total, disc number and total, year, genre and cover it may change; the choice must persist, and cover must be unticked until chosen. |
| **FR-AF-02** | The application must look the record up on MusicBrainz (and the cover on the Cover Art Archive) only when the owner starts an autofill, identify itself, and send at most one request a second. |
| **FR-AF-03** | The best-matching release must be preselected, every other candidate must be selectable, and the search must be editable. |
| **FR-AF-04** | Every proposed change must be shown per file as the current value and the new one, each with its own confirmation; values that would not change must not be shown. |
| **FR-AF-05** | Only confirmed changes may be written (for a batch, those `FR-AF-10` allows), only into the file's metadata, and a file changed since it was read must not be written. A format that cannot be written without losing other metadata must not be offered: only MP3 and FLAC are written, each by an editor that changes only the frames or comments asked for and keeps every other byte, and a format is written only once tests prove a write loses nothing else. M4A, WAV, APE, OGG, Opus and the rest are read-only. A write must go to a temporary file beside the track and be renamed into place, through a symbolic link to the real file. |
| **FR-AF-06** | Written changes must reach the library, and every screen, without the owner starting a scan. |
| **FR-AF-07** | A file that could not be written must be named with the reason, and a file refused because it was in use must be retryable. |
| **FR-AF-08** | On Android 11 and later, all-files access must be asked for only when the owner confirms an autofill or a tag edit. On Android 7 to 10, write access is granted together with read access, in the same system dialog, and must only ever be used for an autofill or a tag edit the owner confirmed. Either way, a refusal must write nothing. For a batch (`FR-AF-09`) the access is asked for once, when the owner confirms the start and before anything is looked up, and a refusal starts nothing and says so. |
| **FR-AF-09** | The owner must be able to start an autofill on a selection of songs, an artist, a genre, a playlist or the whole library, choosing the tags as in `FR-AF-01`. Before anything is looked up, Orpheus must say how many songs and records it covers, roughly how long it will take, that confident matches are written without review and replace existing values, and how many songs cannot be changed, and must be told to start. A record's own menu keeps the reviewed autofill of `FR-AF-01`. |
| **FR-AF-10** | The songs must be split into records and lone tracks by album artist (else artist) and album, a folder of songs with no album being one record and a lone song a lone track, and each looked up as in `FR-AF-02` and `FR-AF-03`, over every song of the album the library holds when only part of it is in the batch. A record must be written without review only when its match is confident: an official release of the same title and artist, each song of the batch given a track of the same title and, where the song has them, the same numbers, and no change to the album or album artist of a record some of whose songs will not be written — left out of the batch, of a format Orpheus does not write, or with tags it cannot change safely. A lone track must be written without review only when the recording's title and artist are the song's, its length is within 3 seconds of the song's (an unknown length is a doubt), and the release it is filed under is official, of primary type album and not a compilation. Every other record or lone track must be kept, unwritten, for the owner to review as in `FR-AF-04`, with the reason it is doubtful. A song whose tags cannot be changed safely must be counted and left out, and the rest of its record proceed. |
| **FR-AF-11** | The batch must show its progress, keep running while the owner uses the rest of Orpheus, show an indicator outside its own screen, and stop when asked after the record being written, keeping what was written. A lookup that fails must be tried once more after the next record, and three in a row must pause the batch with the choice to try again or stop. At the end it must say how many records were updated, how many need the owner, how many were already right, and which were not found, could not be changed, could not be written or looked up, or were not looked up, and why; files refused because they were in use or failed must be retryable as in `FR-AF-07`. Only one batch may exist at a time, and nothing of it survives closing Orpheus. |

### 2.9 Visualisation (VZ)

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

### 2.10 Tag editing (TE)

Realises F-18, F-19 and F-20.

| ID | Requirement |
| --- | --- |
| **FR-TE-01** | The owner must be able to edit, from a single track's menu, its title, artist, album artist, album, track number and total, disc number and total, year, genre and front cover, starting from what the file itself holds. A cover must be a JPEG or a PNG. |
| **FR-TE-02** | A field the file's format cannot hold must be shown as not editable, and a file Orpheus cannot write must say so and offer nothing to save. |
| **FR-TE-03** | Only the fields the owner changed may be written, through the same writer and under the same rules as `FR-AF-05`, measured against the file as it was when the editor read it; a field cleared removes the tag. Track and disc numbers and totals must be whole numbers of one or more, a total must have its number (ID3 cannot hold one without the other), and the year from 1 to 9999. |
| **FR-TE-04** | A saved edit must reach the library and every screen without the owner starting a scan. A file that could not be written must be named with the reason as in `FR-AF-07`, keeping the owner's edits, and one changed by another program since it was read must offer to be read again. |
| **FR-TE-05** | The owner must be able to edit, from an album's or an artist's menu, the artist, album artist, album, track total, disc number and total, year, genre and front cover of all its tracks in one form. A field the tracks disagree on must be shown as mixed; title and track number are not offered for more than one track. |
| **FR-TE-06** | Tracks Orpheus cannot write (`FR-TE-02`) must be named before the owner saves and left alone; a field none of the tracks can hold is not editable. |
| **FR-TE-07** | Only the fields the owner changed may be written, to each track that can hold them, under the rules of `FR-TE-03`, each track measured against itself as it was read; a mixed field left alone is written to none, and a track that already holds the value is not written for it. |
| **FR-TE-08** | Each track that could not be written must be named with its reason as in `FR-AF-07`, without undoing the tracks that were; those in use, failed or changed since read can be tried again. The library updates without the owner starting a scan. |
| **FR-TE-09** | The owner must be able to edit the tags of the songs selected under `FR-UX-11` in one form, as in `FR-TE-05` … `FR-TE-08`; one selected song opens the form of a single track (`FR-TE-01`). The selection must end once the form has written at least one song, and stay when it wrote none. |

### 2.11 Playlists (PS)

Realises F-21 and F-22.

| ID | Requirement |
| --- | --- |
| **FR-PS-01** | The owner must be able to create a playlist by giving it a name, rename it, and delete it. A name is trimmed and must not be blank; two playlists may share one, since the name is a label and each playlist has an identity of its own. Deleting asks first, and removes the playlist and its cover and nothing else: no song and no file is touched. |
| **FR-PS-02** | The owner must be able to add to a playlist a song, the songs of a selection (`FR-UX-11`), a whole album, or a whole artist, from that item's menu, the selection's bar or right-click menu, or a playlist's own selection. They are chosen from a list of the playlists, most recently changed first, which offers *New playlist…* ahead of them. The songs go at the end, in the order given: a selection in the order of its list, an album in track order, an artist in the order the artist is listed. What was actually added is said afterwards. |
| **FR-PS-03** | A playlist may hold the same song more than once. When some of the songs being added are already in the chosen playlist, the owner must be asked whether to add them anyway, to skip those songs, or to cancel, and nothing is added until they answer. |
| **FR-PS-04** | Each place in a playlist is an entry of its own, carrying the song's file and what the song was called, who by, from which record and how long, as they were when it was added or last saved while the library had the song. An entry must be removable one at a time, from its song's menu or from a selection; removing never touches the song or its file. |
| **FR-PS-05** | The owner must be able to reorder a playlist by dragging a song's handle; the new order is saved at once. Dragging is not offered while a selection is made in the playlist. |
| **FR-PS-06** | A playlist's cover must be the JPEG or PNG picture the owner chose for it, kept in the application's own data as a file of its own, or, when they chose none, a mosaic of the covers of up to four of its distinct albums. The owner must be able to remove the picture they chose. |
| **FR-PS-07** | The shell's Playlists destination must list the playlists, the most recently changed first, as rows or as tiles by the owner's layout choice, each with its cover, its name and its number of songs, with *New playlist* above them and each playlist's menu on its ⋮ button, a right-click and a touch and hold. Opening one shows its songs in the owner's order, and Back closes it before it leaves the destination. |
| **FR-PS-08** | The owner must be able to play a playlist, or shuffle it, from its header, and to play it from a song by tapping that song. What plays is the playlist's songs the library holds, from the tapped song on, and the queue is named after the playlist. |
| **FR-PS-09** | A song whose file the library no longer holds must stay in its playlist, shown greyed and labelled as missing with what was saved of it, must be skipped when the playlist plays, and may be selected and removed. Whether a song is missing must not be decided before the library has loaded, so that a library still being read does not show every song missing. |
| **FR-PS-10** | A selection made inside a playlist must count each entry on its own, so that ticking one copy of a song does not tick another. Its actions are *Remove from playlist*, *Add to playlist…* and *Edit tags…* (`FR-TE-09`); the last two act on the songs the library holds, each once, in the playlist's order. |
| **FR-PS-11** | The owner must be able to export a playlist to an extended M3U file, in UTF-8, saved where the owner chooses. Each entry is written, a missing one as well, with its length, `artist - title` and the file's absolute path, from the library when the song is in it and from what was saved when it is not. A name that is not safe as a file name on Windows is made safe. Cancelling the dialog is not a failure and writes nothing; a file that could not be written is reported. |
| **FR-PS-12** | The playlists must be stored in the application's own data, in one versioned document, never in a music folder. Every change must be written whole and atomically, and shown only once it is stored; a change that could not be written must be reported and leave what was stored as it was. A scan, or a folder that cannot be reached, must never change a playlist. |
| **FR-PS-13** | A stored document that cannot be understood, or that was written by another version, must be kept aside under a name of its own, with the time, and never overwritten; the application then starts with no playlists. When it can neither be read nor kept aside, the Playlists destination must show the error with a retry, and nothing may be written over the document. |
| **FR-PS-14** | The Playlists destination must offer two playlists that Orpheus keeps by itself from the play history, *Favourites lately* and *All-time favourites*, each with its cover, its name and its number of songs, in an *Auto playlists* section above the owner's own, which follow under *Your playlists*. The cover is the mosaic of up to four of its albums' covers. They are worked out from the play history, the library and the clock, and are never stored: nothing of them is written to the playlists document, and they do not appear among the owner's playlists. |
| **FR-PS-15** | *Favourites lately* must hold the songs the owner has played most in the last 30 days, the most plays first and, among equal counts, the more recently played first, up to 50. It counts the dated plays of `FR-ST-16`. Until at least 10 songs have a dated play in the last 30 days, it must instead hold the songs last played in the last 30 days, the song with the most plays in all first and, among equal counts, the more recently played first, up to 50, and say *Getting to know your recent listening* under its header while it does. With no song to show it says *Play some music and your recent favourites will show here* and no such note. |
| **FR-PS-16** | *All-time favourites* must hold the songs the owner has played most in all, the most plays first and, among equal counts, the more recently played first, up to 50. With no song played it says *Play some music and your favourites will show here*. |
| **FR-PS-17** | A song the library does not hold must be left out of both, as must every song while the library has not loaded. A song already in the history comes back into them when the library holds it again. |
| **FR-PS-18** | Both must follow the owner's listening by themselves, with no action to refresh them: they are worked out again when a play is recorded and when the library changes. An auto playlist that is open may therefore change order or songs under the owner; a selection made in it follows the songs it holds. |
| **FR-PS-19** | An auto playlist must open as a playlist does, with *Play* and *Shuffle*, a song to play from, and the song's own menu, but must be read-only: no drag handle, no *Remove from playlist*, no rename, cover or delete. Its menu — its ⋮ button, a right-click or a touch and hold — must offer *Add to playlist…*, which copies all its songs into a playlist of the owner's (`FR-PS-02`, `FR-PS-03`), and *Export to .m3u…*, which writes the file as `FR-PS-11` says, named after the auto playlist. A selection made in it must offer *Add to playlist…* and *Edit tags…* (`FR-TE-09`) over the songs selected, and nothing else. |
| **FR-PS-20** | The *Auto playlists* section must stand on its own: it must show when the owner has no playlists, which then says so in a line under *Your playlists* with *New playlist*, and when the owner's playlists could not be read, above that error. A line of loading stands in for it while the library is read, and it is not shown when the library could not be. |
| **FR-PS-21** | The owner must be able to turn the auto playlists off and on with *Show auto playlists* in the preferences, on by default; the choice applies at once and is kept (`FR-UX-06`). Off, the section is not shown and an auto playlist that is open closes; the plays keep being recorded, so that turning it on finds the lists as the listening has made them. |

### 2.12 Data export (DX)

Realises F-23.

| ID | Requirement |
| --- | --- |
| **FR-DX-01** | The preferences must have a *Your data* section with *Export my data (JSON)…*, which saves the owner's data to one JSON file at the place the owner chooses in the save dialog, suggesting `orpheus-data-<yyyy-MM-dd>.json` for the day it was asked. Cancelling the dialog writes nothing and is not a failure. |
| **FR-DX-02** | The file must hold every song of the library with its path and the tags and length the catalog holds; the artists and the albums as the library lists them, each naming its songs; the owner's playlists, each entry with the path and the details saved with it, and whether the playlist has a cover of its own; both auto playlists, whatever *Show auto playlists* says (`FR-PS-21`); the play history, including songs the library no longer holds; the statistics as the statistics screen shows them (`FR-ST-08` … `FR-ST-12`); and the layout's version, the application's version when it is known, and the time. It must not hold cover images, audio or preferences. |
| **FR-DX-03** | The file's layout must be documented in `docs/data-export.md`, field by field, and versioned: a `format` of `orpheus-data` and an integer `formatVersion`, now 1, which a change that could break a reader must raise. It must be UTF-8, indented by two spaces, with its keys in the documented order, times as ISO-8601 UTC strings, durations as whole milliseconds, and a tag the song does not have as `null` rather than left out. Songs must be referred to by an `id` that exists only inside the file, and a reference to a song the library does not hold must be `null`, beside the path. A test must hold the document's top-level keys to the ones the application writes. |
| **FR-DX-04** | The export must only read the owner's data: nothing it reads may be changed, and the only thing written is the file the owner chose (`NFR-03`). |
| **FR-DX-05** | The export must wait for the library, the playlists and the play history to finish loading rather than present a section that is empty only because it is not loaded yet; it shows that it is working, and only one runs at a time. |
| **FR-DX-06** | When the library fails to load the export must be refused, with a message saying so, and the save dialog must not be offered: with no songs there is nothing meaningful to save. A library that is being rebuilt, because its stored catalog was refused as another version's or could not be read at all and is owed a scan, is reported as a problem instead (`FR-DX-07`); a library never scanned, or scanned and holding no music, reads as empty, and an export with no songs and no problem means Orpheus found no music. |
| **FR-DX-07** | When the playlists could not be read, the play history could not be read in this run, or the library is being rebuilt (`FR-DX-06`), the export must still complete: that section is empty, `problems` names the section and says why, and the owner is told the export is partial. A playlists or play history document that was kept aside and replaced by an empty one (`FR-PS-13`, `FR-ST-18`) is not a source that could not be read. |
| **FR-DX-08** | Building and encoding the file must not freeze the window, however large the library: it runs off the interface's thread. |
| **FR-DX-09** | The result must be said under the *Export my data (JSON)…* entry, where the owner is looking, and stay until the next export starts or the preferences close: *Exported to* and the place when the system gives one, *Exported* when it does not, *Exported, but some data could not be read* for a partial file, *Your library couldn't be read, so there's nothing to export*, or *Couldn't export your data* when the file could not be written, in which case nothing else is written either. Cancelling says nothing. |

### 2.13 Backup and restore (BK)

Realises F-24.

| ID | Requirement |
| --- | --- |
| **FR-BK-01** | The *Your data* section of the preferences (`FR-DX-01`) must offer *Back up Orpheus (ZIP)…* beside *Export my data (JSON)…*, which saves a ZIP file at the place the owner chooses in the save dialog, suggesting `orpheus-backup-<yyyy-MM-dd>.zip` for the day it was asked. Cancelling the dialog writes nothing and is not a failure. |
| **FR-BK-02** | The ZIP must hold `backup.json`, saying what it is and when it was made and naming its other files; `data.json`, the document of `FR-DX-02` exactly as the JSON export writes it; `preferences.json`, the owner's theme, language, the four switches (open the player when a track starts, re-scan at every launch, look up missing lyrics online, check for updates at startup), *Show auto playlists*, volume and music folders; and, for each playlist with a cover of its own, that picture under `covers/` named by the playlist's id. A restore must read no cover larger than 20 MB uncompressed, whatever size the entry declares, inflating a compressed one no further than that, and must treat a cover it leaves out, for that or because it cannot be read, as one that could not be saved (`FR-BK-19`); choosing a picture over 20 MB as a playlist's cover must be refused, so that a backup does not hold one. It must not hold audio, the library's cover cache or the update version the owner chose to skip, which is a fact about one device. |
| **FR-BK-03** | The ZIP's layout must be documented in `docs/data-export.md` (*Backup file*) and versioned: a `format` of `orpheus-backup` and an integer `formatVersion`, now 1, under the rules of `FR-DX-03`, apart from `data.json`'s. A test must hold the keys of `backup.json` and `preferences.json` to the ones the application writes. |
| **FR-BK-04** | Each of the two exports must say in a line under its entry what it is for, and an *About these exports* link must show, side by side, what each holds: songs, playlists, auto playlists and play history in both; playlist covers and preferences, with the music folders, only in the ZIP; the owner's music files in neither. |
| **FR-BK-05** | A backup must do what `FR-DX-04`, `FR-DX-05` and `FR-DX-08` require of an export: only read the owner's data and write the one file the owner chose, wait for the library, the playlists and the play history to load, show that it is working, and run one at a time, and build and encode the ZIP off the interface's thread. |
| **FR-BK-06** | When the library fails to load the backup must be refused as `FR-DX-06` says. When a source could not be read (`FR-DX-07`), or a playlist's cover picture could not, the backup must still be saved, with the picture left out or the section empty and `problems` saying why, and the owner told. The result must be said under the entry, as `FR-DX-09` says for an export: *Backed up to* and the place, or *Backed up* when the system gives none, *Backed up, but some data could not be read*, *Your library couldn't be read, so there's nothing to back up*, or *Couldn't back up Orpheus*. |
| **FR-BK-07** | The *Your data* section must offer *Restore from a backup…*, which asks for a file ending in `.zip` or `.json` and reads it, off the interface's thread, as a backup ZIP or a data JSON (`FR-DX-03`). Cancelling the dialog does nothing. |
| **FR-BK-08** | A ZIP must hold a `backup.json` whose `format` is `orpheus-backup` and a `data.json` whose `format` is `orpheus-data`, each with a supported `formatVersion`; a JSON must be the latter. Any other file must be refused with *This isn't an Orpheus backup*, and a file of a higher `formatVersion` than this release reads with *This backup is from a newer Orpheus — update first*; nothing is written either way. A ZIP without a readable `preferences.json` must still be restored, without preferences, and a cover that cannot be read is passed over. |
| **FR-BK-09** | Reading a file must show a restore screen with two stages, and nothing may be written before the owner presses *Continue* in the first or *Restore* in the second. The first stage, *Your music*, is shown for a ZIP only. The screen must not be left while the library is being scanned or the parts are being written, and a restore must run one at a time. |
| **FR-BK-10** | The first stage must show the music folders the backup names, each marked as found on this device or not, and this device's folders; it must let the owner choose this device's folders with *Choose folders…* and take one out, the set chosen becoming the **whole** set, so that a folder not in it is removed from the library (`BR-02`). A device with no folders must start with the backup's folders that are found on it, chosen but not yet applied. The screen must say that *Continue* changes the music folders now and scans the library, and that cancelling later keeps them. *Continue* must apply a changed set and scan the library with progress before the second stage, and with no change must go on at once, scanning first only when there are folders and the library is empty or another version's. A scan that fails must not stop the restore. Should something unforeseen stop the restore before the choices show, the failure screen must say, when the folders were changed, that they stay as they are now. The music folders must change in no other way (`NFR-03`). |
| **FR-BK-11** | The second stage, *What to restore*, must show, before anything is written, what the file holds (the date it was made, how many playlists, how many songs with plays, how many playlist covers, and whether it holds preferences), and a choice for each of the playlists, the play history and the preferences: *Merge*, *Skip* or *Replace*, each *Merge* until the owner chooses, with a line saying what the chosen one does for that part. *Replace* must show what it removes: how many playlists, and how many songs' play counts. It must offer *Restore* and *Cancel*. |
| **FR-BK-12** | A part that the backup could not read when it was made, because its data document's `problems` names `playlists` or `playHistory`, must be offered as *Not in this backup* and never restored, so that *Replace* cannot wipe real data with an empty section; a `songs` problem only means fewer songs to match by. The preferences must be offered as *Not in this file* when the file holds none, as a data JSON never does. A part whose data here could not be read must say so and not be restored. |
| **FR-BK-13** | A backup's songs must be matched to the library as it is when the choices are shown, after the first stage's scan for a ZIP: by path, a path under the one folder of the backup first moved to the same place under the one folder of this device when each has exactly one; then by tags, the same title, artist and album ignoring case and surrounding spaces and a length within 2 seconds, only when exactly one library song answers. A matched song's data must go to the library song's path; one that is not matched must keep the backup's path. |
| **FR-BK-14** | *Playlists* must be told apart by name. *Merge* must add the backup's playlists whose name is not here; give the playlist here with a backup playlist's name (the most recently changed, if several) the backup's entries whose song it does not hold, appended in the backup's order; and give a cover only to a playlist here that has none. *Skip* must only add the backup's playlists whose name is not here. *Replace* must remove every playlist here, with its cover, and create the backup's, with their covers. |
| **FR-BK-15** | *Play history*, by song, under *Merge* must keep the higher of the counts here and in the backup, raised to the number of dated plays that remain once both lists are put together if that is higher, the later last play, and every dated play of either from the last 90 days once, and add the songs only the backup holds. *Skip* must only add songs with no history here. *Replace* must put the backup's history in place of this one. |
| **FR-BK-16** | *Preferences* under *Merge* must apply the backup's value for each setting whose value here equals a fresh install's, since the store cannot tell a setting never changed from one set back to its default, and keep the others; *Skip* must change none; *Replace* must apply all eight values, the volume and a language that follows the system included. The music folders must not be one of them (`FR-BK-10`). |
| **FR-BK-17** | Every playlist a restore adds, and every entry in it, must get a new identifier from the application's generator, because a backup's may be one already used here, and its cover must be stored under the new identifier. |
| **FR-BK-18** | A restore must write the playlists, then the play history, then the preferences, each part whole or not at all: the playlists as one write of the whole list and the history as one write of the whole history, a cover afterwards and best-effort, so that a playlist whose picture cannot be stored is still restored. A part whose data here could not be read must be refused with its reason and nothing of it written; a part that fails must not stop the others, and parts already written stay. |
| **FR-BK-19** | When the restore has finished a summary must say what was restored, under *Restored* — playlists added, merged or replaced, play history for how many songs and how many of them the library does not hold, preferences applied, the playlists whose cover picture could not be saved, or was too large to read (`FR-BK-02`), and preferences that applied but could not be saved — and what was not, under *Couldn't restore*, each with its reason: the backup could not read the part when it was made, the file does not have it, it could not be read here and was left alone, or it could not be saved and nothing of it changed. The auto playlists and the statistics follow the new history by themselves. |
| **FR-BK-20** | A restore must never rename, move, delete or change a music file (`NFR-03`); its writes must be to the application's own data and preferences (`IR-05`), and to the music folders' registration only as `FR-BK-10` says. |

## 3. Non-functional requirements

| ID | Requirement |
| --- | --- |
| **NFR-01** | **One source, three targets.** Windows, Linux and Android must build from the same source with no per-platform implementation of any feature above the platform edges. |
| **NFR-02** | **Three network calls, named.** The application must make no network request other than the lyrics lookup of `FR-LY-13`, the MusicBrainz and Cover Art Archive lookups an autofill makes when the owner starts one (`FR-AF-02`), and, on Windows and Linux, the release check of `BR-03` — the one request at startup for the newest release (the latest full release, or for a build that is itself a pre-release, the release list), and the download of an installer and its checksums the owner accepted. No telemetry, analytics, crash reporting, scrobbling or other lookup may be added. The Android package must declare exactly the permissions its manifest lists, and this must be verifiable from the built package. |
| **NFR-03** | **Audio files are changed for confirmed tags only.** No audio file may be renamed, moved, deleted or re-encoded, and its tags may be written only for changes the owner confirmed, one by one or, for a batch autofill, by starting it after being told that its confident matches are written without review (`FR-AF-05`, `FR-AF-09`, `FR-TE-03`, `FR-TE-07`). Exporting a playlist, the owner's data or a backup writes only the file the owner chose (`FR-PS-11`, `FR-DX-04`, `FR-BK-05`), and restoring from a backup changes no audio file: the music folders change only through the restore's first stage, which the owner confirms (`FR-BK-10`, `FR-BK-20`). |
| **NFR-04** | **Startup is not gated on a scan.** The library from the last scan must be on screen before a new scan is started. |
| **NFR-05** | **Scanning is proportional to change.** Re-scanning an unchanged library must not re-parse it. |
| **NFR-06** | **The cover cache is proportional to records, not files.** |
| **NFR-07** | **Testability at the edges.** Every outward dependency must sit behind an interface bound in one composition root, and must be overridable in a test. |
| **NFR-08** | **No test may reach outside its process** — not to the developer's preferences, their application-support folder, their listening statistics, the native audio engine, a platform media service, a music folder, or the network. The lyrics lookup, the sidecar writer, the metadata source and the tag writer must be overridable, and no test may open a socket. |
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
| F-04 Browsing | FR-CT-01, FR-CT-03, FR-CT-04, FR-CT-05, FR-CT-10, FR-CT-11, FR-CT-12 … FR-CT-19 |
| F-05 Search | FR-CT-07, FR-CT-08, FR-CT-09 |
| F-06 Playback | FR-PL-01 … FR-PL-07, FR-PL-20 |
| F-07 Repeat and resume | FR-PL-08 … FR-PL-13 |
| F-08 Now playing | FR-PL-16, FR-PL-17, FR-PL-18, FR-PL-19 |
| F-09 Resilient playback | FR-PL-14, FR-PL-15 |
| F-10 Background playback | FR-BG-01 … FR-BG-10 |
| F-11 Listening statistics | FR-ST-01 … FR-ST-15, FR-ST-20 |
| F-12 Adaptive shell | FR-UX-01, FR-UX-02, FR-UX-03, FR-UX-10 |
| F-13 Preferences | FR-UX-04, FR-UX-05, FR-UX-06, FR-PL-18, FR-LB-18, FR-PS-21, FR-DX-01, FR-BK-01, FR-BK-07 |
| F-14 Localization | FR-UX-09, FR-CT-06 |
| F-15 Lyrics | FR-LY-01 … FR-LY-17 |
| F-16 Sound bars | FR-VZ-01 … FR-VZ-11 |
| F-17 Autofill tags | FR-AF-01 … FR-AF-08 |
| F-18 Edit a track's tags | FR-TE-01 … FR-TE-04 |
| F-19 Edit the tags of several tracks | FR-TE-05 … FR-TE-08 |
| F-20 Select several songs | FR-UX-11, FR-UX-12, FR-UX-13, FR-TE-09 |
| F-21 Playlists | FR-PS-01 … FR-PS-13, FR-UX-01 |
| F-22 Auto playlists | FR-PS-14 … FR-PS-21, FR-ST-16 … FR-ST-20, FR-UX-06 |
| F-23 Export my data | FR-DX-01 … FR-DX-09 |
| F-24 Back up and restore | FR-BK-01 … FR-BK-20 |
| F-25 Autofill many songs at once | FR-AF-09 … FR-AF-11 |

### 4.2 Requirements to use cases

| Area | Use cases |
| --- | --- |
| LB | UC-01, UC-02, UC-03, UC-04, UC-05, UC-06 |
| CT | UC-07, UC-08, UC-09, UC-10, UC-11, UC-12, UC-36 |
| PL | UC-13 … UC-23 |
| BG | UC-24, UC-25 |
| ST | UC-26, UC-27, UC-40 |
| UX | UC-28, UC-29, UC-38, UC-39 |
| LY | UC-30, UC-31, UC-33 |
| VZ | UC-32 |
| AF | UC-34, UC-44 |
| TE | UC-35, UC-37, UC-38 |
| PS | UC-39, UC-40 |
| DX | UC-29, UC-41 |
| BK | UC-29, UC-42, UC-43 |

## 5. Data model

Everything the application persists, and where.

| Document | Location | Contents |
| --- | --- | --- |
| **Catalog** | `catalog.json` in the application-support directory | One entry per audio file: path, size, modification time, and every tag read from it — every genre a file holds, not only the first — plus the id of its cover. Written atomically; versioned. |
| **Playlists** | `playlists.json`, beside the catalog | The owner's playlists: for each, its id, name, the id of its cover picture if the owner chose one, when it was made and last changed, and its entries in order — each with its own id, the file's path, and the title, artist, album and length it had when it was added or last saved while the library had the song. Written whole and atomically; versioned. A document that cannot be read, or that has another version, is renamed `playlists.json.bad-<time>` and not overwritten. |
| **Playlist covers** | a `playlist-covers` directory | The picture the owner chose for a playlist, one file per playlist, named by the playlist's id. |
| **Play history** | `play-history.json`, beside the catalog | One entry per file ever played: path, play count, when it last counted, and the dates of its plays from the last 90 days. Written atomically; versioned, now 2. A version-1 document is read as it stands, copied once to `play-history.json.v1`, and written as version 2 by the next play. A document that cannot be read is renamed `play-history.json.bad-<time>`, and one with rows stepped over is copied to that name; neither is overwritten. |
| **Cover cache** | a `covers` directory | One file per distinct picture, named by the hash of its bytes. |
| **Analysis cache** | an `energy` directory | One file per analysed track — the measured spectrum, about a hundred kilobytes for a four-minute track — named by a key carrying the file's path, length and modification time. Disposable: deleting it costs a second per track and nothing else. |
| **Preferences** | the platform's own preference store | Library folders, theme, language, layout, volume, repeat mode, resume points, the skipped update version, and the switches: open the player when a track starts, re-scan the library at every launch, look up missing lyrics online, check for updates at startup, and *Show auto playlists*. |

Lyrics are deliberately absent from this table, because this application's own
directory never holds any. They are read from the owner's own files each time
the player asks for them — which is what keeps a corrected `.lrc` correct the
moment it is saved, with nothing to invalidate. A sheet obtained by lookup is
written beside the track it belongs to, as a `.lrc` the owner and every other
player on the machine can read, and is thereafter one of those files rather
than a cache of anything (`BR-32`).

Nothing else is written, and nothing is written outside these locations
(`BR-02`).
