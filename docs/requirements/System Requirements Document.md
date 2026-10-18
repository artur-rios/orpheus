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
| **FR-ST-07** | A play history that cannot be read must start over rather than prevent the application from running. |
| **FR-ST-08** | The application must present the total number of plays and the number of distinct tracks they came from. |
| **FR-ST-09** | The application must present four rankings — most played tracks, artists, records and genres — read from the play history against the catalog (`BR-23`). A track with several genres must credit each of them with its plays, and a genre's share of the plays must be of all plays, so shares may add up to more than 100%. |
| **FR-ST-10** | Every ranking must be drawn even when it is empty. |
| **FR-ST-11** | A played track whose tags name no artist, record or genre must be counted in the totals, excluded from those rankings, and the discrepancy must be explained on screen (`BR-24`). A track has no genre only when it has none at all. |
| **FR-ST-12** | A played file the catalog no longer holds must still count, and must be named by its file. |
| **FR-ST-13** | The statistics must be read once per opening and must not reorder themselves while being read; reading them again must be one action away. |
| **FR-ST-14** | The statistics screen must not fail because the library could not be read. |
| **FR-ST-15** | Before anything has been played, the screen must state what makes a track count. |

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
| **FR-UX-13** | In a window narrower than 480 logical pixels, the actions in a selection's bar must be icons with tooltips, so that the count of what is selected keeps its room. |

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

Realises F-17.

| ID | Requirement |
| --- | --- |
| **FR-AF-01** | The owner must be able to start an autofill on a record or on a single track, and choose which of title, artist, album artist, album, track number and total, disc number and total, year, genre and cover it may change; the choice must persist, and cover must be unticked until chosen. |
| **FR-AF-02** | The application must look the record up on MusicBrainz (and the cover on the Cover Art Archive) only when the owner starts an autofill, identify itself, and send at most one request a second. |
| **FR-AF-03** | The best-matching release must be preselected, every other candidate must be selectable, and the search must be editable. |
| **FR-AF-04** | Every proposed change must be shown per file as the current value and the new one, each with its own confirmation; values that would not change must not be shown. |
| **FR-AF-05** | Only confirmed changes may be written, only into the file's metadata, and a file changed since it was read must not be written. A format that cannot be written without losing other metadata must not be offered: only MP3 and FLAC are written, each by an editor that changes only the frames or comments asked for and keeps every other byte, and a format is written only once tests prove a write loses nothing else. M4A, WAV, APE, OGG, Opus and the rest are read-only. A write must go to a temporary file beside the track and be renamed into place, through a symbolic link to the real file. |
| **FR-AF-06** | Written changes must reach the library, and every screen, without the owner starting a scan. |
| **FR-AF-07** | A file that could not be written must be named with the reason, and a file refused because it was in use must be retryable. |
| **FR-AF-08** | On Android 11 and later, all-files access must be asked for only when the owner confirms an autofill or a tag edit. On Android 7 to 10, write access is granted together with read access, in the same system dialog, and must only ever be used for an autofill or a tag edit the owner confirmed. Either way, a refusal must write nothing. |

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

Realises F-21.

| ID | Requirement |
| --- | --- |
| **FR-PS-01** | The owner must be able to create a playlist by giving it a name, rename it, and delete it. A name is trimmed and must not be blank; two playlists may share one, since the name is a label and each playlist has an identity of its own. Deleting asks first, and removes the playlist and its cover and nothing else: no song and no file is touched. |
| **FR-PS-02** | The owner must be able to add to a playlist a song, the songs of a selection (`FR-UX-11`), a whole album, or a whole artist, from that item's menu, the selection's bar or right-click menu, or a playlist's own selection. They are chosen from a list of the playlists, most recently changed first, which offers *New playlist…* ahead of them. The songs go at the end, in the order given: a selection in the order of its list, an album in track order, an artist in the order the artist is listed. What was actually added is said afterwards. |
| **FR-PS-03** | A playlist may hold the same song more than once. When some of the songs being added are already in the chosen playlist, the owner must be asked whether to add them anyway, to skip those songs, or to cancel, and nothing is added until they answer. |
| **FR-PS-04** | Each place in a playlist is an entry of its own, carrying the song's file and what the song was called, who by, from which record and how long, as they were when it was added. An entry must be removable one at a time, from its song's menu or from a selection; removing never touches the song or its file. |
| **FR-PS-05** | The owner must be able to reorder a playlist by dragging a song's handle; the new order is saved at once. Dragging is not offered while a selection is made in the playlist. |
| **FR-PS-06** | A playlist's cover must be the JPEG or PNG picture the owner chose for it, kept in the application's own data as a file of its own, or, when they chose none, a mosaic of the covers of up to four of its distinct albums. The owner must be able to remove the picture they chose. |
| **FR-PS-07** | The shell's Playlists destination must list the playlists, the most recently changed first, as rows or as tiles by the owner's layout choice, each with its cover, its name and its number of songs, with *New playlist* above them and each playlist's menu on its ⋮ button, a right-click and a touch and hold. Opening one shows its songs in the owner's order, and Back closes it before it leaves the destination. |
| **FR-PS-08** | The owner must be able to play a playlist, or shuffle it, from its header, and to play it from a song by tapping that song. What plays is the playlist's songs the library holds, from the tapped song on, and the queue is named after the playlist. |
| **FR-PS-09** | A song whose file the library no longer holds must stay in its playlist, shown greyed and labelled as missing with what was saved of it, must be skipped when the playlist plays, and may be selected and removed. Whether a song is missing must not be decided before the library has loaded, so that a library still being read does not show every song missing. |
| **FR-PS-10** | A selection made inside a playlist must count each entry on its own, so that ticking one copy of a song does not tick another. Its actions are *Remove from playlist*, *Add to playlist…* and *Edit tags…* (`FR-TE-09`); the last two act on the songs the library holds, each once, in the playlist's order. |
| **FR-PS-11** | The owner must be able to export a playlist to an extended M3U file, in UTF-8, saved where the owner chooses. Each entry is written, a missing one as well, with its length, `artist - title` and the file's absolute path, from the library when the song is in it and from what was saved when it is not. A name that is not safe as a file name on Windows is made safe. Cancelling the dialog is not a failure and writes nothing; a file that could not be written is reported. |
| **FR-PS-12** | The playlists must be stored in the application's own data, in one versioned document, never in a music folder. Every change must be written whole and atomically, and shown only once it is stored; a change that could not be written must be reported and leave what was stored as it was. A scan, or a folder that cannot be reached, must never change a playlist. |
| **FR-PS-13** | A stored document that cannot be understood, or that was written by another version, must be kept aside under a name of its own, with the time, and never overwritten; the application then starts with no playlists. When it can neither be read nor kept aside, the Playlists destination must show the error with a retry, and nothing may be written over the document. |

## 3. Non-functional requirements

| ID | Requirement |
| --- | --- |
| **NFR-01** | **One source, three targets.** Windows, Linux and Android must build from the same source with no per-platform implementation of any feature above the platform edges. |
| **NFR-02** | **Three network calls, named.** The application must make no network request other than the lyrics lookup of `FR-LY-13`, the MusicBrainz and Cover Art Archive lookups an autofill makes when the owner starts one (`FR-AF-02`), and, on Windows and Linux, the release check of `BR-03` — the one request at startup for the newest release (the latest full release, or for a build that is itself a pre-release, the release list), and the download of an installer and its checksums the owner accepted. No telemetry, analytics, crash reporting, scrobbling or other lookup may be added. The Android package must declare exactly the permissions its manifest lists, and this must be verifiable from the built package. |
| **NFR-03** | **Audio files are changed for confirmed tags only.** No audio file may be renamed, moved, deleted or re-encoded, and its tags may be written only for changes the owner confirmed (`FR-AF-05`, `FR-TE-03`, `FR-TE-07`). Exporting a playlist writes only the file the owner chose (`FR-PS-11`). |
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
| F-11 Listening statistics | FR-ST-01 … FR-ST-15 |
| F-12 Adaptive shell | FR-UX-01, FR-UX-02, FR-UX-03, FR-UX-10 |
| F-13 Preferences | FR-UX-04, FR-UX-05, FR-UX-06, FR-PL-18, FR-LB-18 |
| F-14 Localization | FR-UX-09, FR-CT-06 |
| F-15 Lyrics | FR-LY-01 … FR-LY-17 |
| F-16 Sound bars | FR-VZ-01 … FR-VZ-11 |
| F-17 Autofill tags | FR-AF-01 … FR-AF-08 |
| F-18 Edit a track's tags | FR-TE-01 … FR-TE-04 |
| F-19 Edit the tags of several tracks | FR-TE-05 … FR-TE-08 |
| F-20 Select several songs | FR-UX-11, FR-UX-12, FR-UX-13, FR-TE-09 |
| F-21 Playlists | FR-PS-01 … FR-PS-13, FR-UX-01 |

### 4.2 Requirements to use cases

| Area | Use cases |
| --- | --- |
| LB | UC-01, UC-02, UC-03, UC-04, UC-05, UC-06 |
| CT | UC-07, UC-08, UC-09, UC-10, UC-11, UC-12, UC-36 |
| PL | UC-13 … UC-23 |
| BG | UC-24, UC-25 |
| ST | UC-26, UC-27 |
| UX | UC-28, UC-29, UC-38, UC-39 |
| LY | UC-30, UC-31, UC-33 |
| VZ | UC-32 |
| AF | UC-34 |
| TE | UC-35, UC-37, UC-38 |
| PS | UC-39 |

## 5. Data model

Everything the application persists, and where.

| Document | Location | Contents |
| --- | --- | --- |
| **Catalog** | `catalog.json` in the application-support directory | One entry per audio file: path, size, modification time, and every tag read from it — every genre a file holds, not only the first — plus the id of its cover. Written atomically; versioned. |
| **Playlists** | `playlists.json`, beside the catalog | The owner's playlists: for each, its id, name, the id of its cover picture if the owner chose one, when it was made and last changed, and its entries in order — each with its own id, the file's path, and the title, artist, album and length it had when it was added. Written whole and atomically; versioned. A document that cannot be read, or that has another version, is renamed `playlists.json.bad-<time>` and not overwritten. |
| **Playlist covers** | a `playlist-covers` directory | The picture the owner chose for a playlist, one file per playlist, named by the playlist's id. |
| **Play history** | `play-history.json`, beside the catalog | One entry per file ever played: path, play count, and when it last counted. Written atomically; versioned. |
| **Cover cache** | a `covers` directory | One file per distinct picture, named by the hash of its bytes. |
| **Analysis cache** | an `energy` directory | One file per analysed track — the measured spectrum, about a hundred kilobytes for a four-minute track — named by a key carrying the file's path, length and modification time. Disposable: deleting it costs a second per track and nothing else. |
| **Preferences** | the platform's own preference store | Library folders, theme, language, layout, volume, repeat mode, resume points, and the two behaviour switches. |

Lyrics are deliberately absent from this table, because this application's own
directory never holds any. They are read from the owner's own files each time
the player asks for them — which is what keeps a corrected `.lrc` correct the
moment it is saved, with nothing to invalidate. A sheet obtained by lookup is
written beside the track it belongs to, as a `.lrc` the owner and every other
player on the machine can read, and is thereafter one of those files rather
than a cache of anything (`BR-32`).

Nothing else is written, and nothing is written outside these locations
(`BR-02`).
