# Changelog

All notable changes to Orpheus are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Browse and play by genre. A new *Genres* tab, between Music and Queue, lists every genre in the library with its
  number of tracks and their length, and a *No genre* group last. Open one to browse the artists, records and songs
  that carry it, as rows or sleeves, with a breadcrumb back out. A record is listed under every genre any of its
  tracks carries and opens whole; playing a genre, or shuffling it, plays only the tracks tagged with it, and playing
  an artist inside a genre plays that artist's records listed under it. A track with several genres (`Rock; Pop`) is
  under each, genres are matched ignoring case and spaces, and the tab remembers where you were apart from Music.
- A search selector. Under the results, choose *All*, *Songs*, *Artists*, *Albums* or *Genres* to match the term
  against only that kind of tag — a search for *Rock* under *Songs* finds titles, not tracks tagged Rock. The choice is
  kept while Orpheus runs and is *All* again at the next launch; results stay a list of tracks. Genres are now
  searched too, ranked after records.
- Edit the tags of a whole album or artist at once. From an album's or an artist's ⋮ menu — or a right-click or a long
  press — choose *Edit tags…* to change the artist, album artist, album, track total, disc number and total, year and
  genre of every song in it, and to replace its cover or remove it. A field the songs disagree on shows as mixed and is
  left alone unless you type in it; title and track number are not offered for more than one song. Only the fields you
  change are written, each song measured against its own file. MP3 and FLAC files are written; any other format is
  listed before you save and skipped, and a song that cannot be written is named with its reason while the others stay
  written, with *Try again* for those in use, failed, or changed since they were read. An album or artist with one song
  opens the one-track editor.
- Select several songs. In any list of songs — all of them, inside an album or a genre, or search results —
  touch and hold a song, or Ctrl-click or Shift-click it, to start a selection. Tick boxes take the place of the
  track number or cover, a tap picks a song instead of playing it, and Shift-click picks a stretch. A bar above the
  list shows how many are selected, with *Select all*, a ✕ to stop and *Edit tags…*; a right-click on a selected song
  offers the same action as *Edit tags of N songs…*. Esc, ✕, the system Back on Android, or leaving the list ends the selection, and so
  does a save that wrote songs.
- Edit the tags of the selected songs together, even from different albums and artists: the same form as for an album
  or an artist, over exactly those songs. One selected song opens the one-track editor.
- Playlists. A new *Playlists* tab, after Genres, lists them, the most recently changed first, as rows or tiles, with
  *New playlist* at the top. Each playlist's menu — its ⋮ button, a right-click or a touch and hold — has *Rename…*,
  *Choose cover…*, *Remove cover* (only once it has a cover of your own), *Export to .m3u…* and *Delete…*, which asks
  first and never touches a song. The cover is a JPEG or PNG of your own, or else a mosaic of up to four of its albums'
  covers.
- Add to a playlist. *Add to playlist…* is on a song's menu, in the bar and the right-click menu of a selection, and on
  an album's and an artist's ⋮ menu. Pick a playlist, or *New playlist…* first in the list; the songs go at the end, and
  a message says *Added N songs to X*. Songs a playlist already holds are asked about — *Add anyway*, *Skip those* or
  *Cancel* — and a playlist may hold a song more than once.
- Open a playlist to *Play* or *Shuffle* it, or tap a song to play from there. Drag a song's handle to reorder, and use
  *Remove from playlist* on a song's menu or on a selection, which here counts each copy of a song on its own and also
  offers *Add to playlist…* and *Edit tags…*. Back ends a selection, then closes the playlist. A song whose file the
  library no longer has stays in the playlist, greyed out and labelled *Missing*, and is skipped when it plays, so an
  unplugged drive does not empty a playlist.
- Export a playlist to `.m3u`. *Export to .m3u…* writes an extended M3U in UTF-8 to the file you choose, and nothing
  else; the name is made safe for Windows.
- Playlists are kept in `playlists.json` in Orpheus's own data, never in your music folders, and every change is written
  atomically. A document Orpheus cannot read, or that another version wrote, is kept aside as
  `playlists.json.bad-<time>` and never overwritten; if it cannot be set aside, the Playlists tab shows an error and
  nothing is saved over it.
- Auto playlists. An *Auto playlists* section at the top of the Playlists tab, above *Your playlists*, holds two
  playlists Orpheus keeps from what you listen to: *Favourites lately*, the songs you have played most in the last 30
  days, and *All-time favourites*, the songs you have played most ever. Each holds up to 50 songs, most plays first and
  the more recently played first among equals, and a song the library does not hold is left out. Until at least 10
  songs have a play recorded with its date in the last 30 days, *Favourites lately* is the songs played in the last 30
  days by their total plays and says *Getting to know your recent listening*. They fill themselves as you listen. Open
  one to *Play* or *Shuffle* it, tap a song to play from there, or select songs to *Add to playlist…* or
  *Edit tags…*; its menu has *Add to playlist…*, which copies every song into a playlist of your own, and
  *Export to .m3u…*. They cannot be reordered, edited, renamed or deleted, and are never written to `playlists.json`.
- *Show auto playlists* in the preferences, on by default. Off, the section is hidden and an open auto playlist closes;
  your plays are still recorded, so turning it back on finds the lists as your listening has made them.
- Each play is now recorded with its date, and a song keeps the dates of its plays from the last 90 days. That is what
  *Favourites lately* is worked out from; the statistics screen shows the same numbers as before.
- Export my data. *Export my data (JSON)…*, under *Your data* in the preferences, saves your library, playlists, both
  auto playlists, play history and statistics to one JSON file, in a place you choose; the suggested name is
  `orpheus-data-<yyyy-MM-dd>.json`. Songs are listed with their path, tags and length, the playlists with the details
  saved for each song, and the play history with songs the library no longer holds. It waits for the library, the
  playlists and the play history to load and does not freeze the window while it builds the file. It only reads: the one
  thing it writes is the file you chose. If the playlists or the play history cannot be read, or the library is being
  rebuilt after an upgrade or because its catalog could not be read, that section is empty, the file's `problems` says
  why, and Orpheus says *Exported, but some data could not be read*; if the library fails to load, nothing is
  exported. The result is shown under the button. The layout is documented and versioned in `docs/data-export.md`. It
  holds no cover images, audio or preferences; *Restore from a backup…* can read it back, as below.
- Back up and restore. *Back up Orpheus (ZIP)…*, under *Your data*, saves one ZIP, suggested as
  `orpheus-backup-<yyyy-MM-dd>.zip`, that holds the data of *Export my data (JSON)…* exactly as it writes it, the cover
  picture of every playlist that has one, and your preferences with your music folders; the update you chose to skip is
  left out. *About these exports* shows what each file holds, and each says in a line what it is for. Like the export,
  a backup waits for the library, the playlists and the play history, does not freeze the window, only reads, and says
  *Backed up, but some data could not be read* when a source or a cover picture could not be; the layout is documented
  and versioned in `docs/data-export.md`.
- *Restore from a backup…*, under *Your data*, reads a backup ZIP or an exported JSON, and says *This isn't an Orpheus
  backup* or, for a file from a newer Orpheus, *update first*. For a ZIP it first shows the music folders the backup
  names, each found on this device or not, and yours: *Choose folders…* sets the whole set, and *Continue* applies it,
  which changes your music folders now, and scans the library with progress; cancelling later keeps them. Then it shows
  what the file holds and, separately for the playlists, the play history and the preferences, offers *Merge*, *Skip* or
  *Replace*, *Merge* to begin with. *Merge* never loses anything here: playlists are told apart by name and get the
  songs and cover they lack, each song keeps the higher play count, the later last play and the dated plays of both, and
  a preference still at its default takes the backup's. *Skip* adds only what is wholly new. *Replace* says first
  what it removes. Songs are matched to your library by path, with a folder moved from the backup's one music folder to yours,
  and then by title, artist, album and length within 2 seconds when exactly one song answers; one that cannot be matched
  keeps the backup's path. A part the backup could not read is not offered, a part this device could not read is left
  alone, each part is written whole or not at all, and a part that fails does not stop the others. A summary says what
  was restored and what was not, including a playlist whose cover picture was too large (over 20 MB) to read, and a
  cover picture over that size is not accepted when you choose one. If
  something unexpected stops a restore after the music folders were changed, the screen says they stay changed. Your
  music files are never changed. From a JSON, the preferences and the covers are not restored, and it says so.

### Changed

- The first launch of this version scans the library once more, even with *Re-scan the library at every launch*
  turned off, because the catalog now keeps every genre a file holds and not only the first.
- A genre containing a `/` is now one genre in MP3 files, as in every other format: *Hip-Hop/Rap* is no longer read
  as *Hip-Hop* and *Rap*. An MP3's ID3v2.4 genre frame now keeps every value it holds, and numeric references such
  as `(17)` are still read as the genre they name. Genres are split at `;`, `|` and `,`. An MP4 file with several
  genre atoms still keeps only one.
- A track with several genres now counts toward each of them in the statistics, and a genre's share on the story
  card is of all plays, so the shares can add up to more than 100%.
- The album row's autofill button moved into its new ⋮ menu, beside *Edit tags…*.
- Touch and hold on a song now selects it instead of opening its menu, which is on its ⋮ button and a right-click.
  Touch and hold on an album or an artist still opens its menu.
- On a phone, *Edit tags…* in a selection's bar is an icon with a tooltip, where the bar is narrower than 480 logical
  pixels, so the count keeps its room. The bar's other actions are icons at any width.
- The play history, `play-history.json`, is now version 2, and an existing history is migrated: every song keeps its
  count and its last-played date, and it is never reset. The first time a version-1 history is read, a copy is kept
  as `play-history.json.v1`. An earlier release does not read it, but if you install one you can restore it by hand,
  by renaming it to `play-history.json`.
- A play history Orpheus cannot read — not UTF-8 or not JSON, not a play history, or written by another version — is
  no longer started over and overwritten: it is kept aside as `play-history.json.bad-<time>`, and a history with a
  row or date that is not one has the original copied aside under that name before the rest is kept. If it cannot be
  kept aside, no plays are recorded until the next start, so that nothing is written over it; playback is not
  affected.

## [1.4.0] - 2026-10-13

### Added

- Edit a track's tags by hand. From a song's menu — its ⋮ button, a right-click or a long press — choose *Edit tags…*
  to change its title, artist, album artist, album, track and disc numbers and totals, year and genre, and to replace
  its cover with a JPEG or PNG or remove it. Only the fields you change are written, through the same MP3 and FLAC
  editors autofill uses, and the library updates without a scan. A file in use can be tried again, and one another
  program changed since it was read can be reloaded (#53).

## [1.3.0] - 2026-10-12

### Added

- Autofill tags from MusicBrainz. On a record, or from a track's menu, choose which tags to fill — title, artist, album
  artist, album, track and disc numbers and totals, year, genre, and optionally the cover — and Orpheus finds the
  release, shows every change file by file as old → new, and writes only the ones you leave ticked, into the files and
  the library. Another release or another search is one tap away. Orpheus now changes audio files for this and nothing
  else; on Android 11 and later the app asks for all-files access the first time you confirm an autofill (on Android
  7 to 10 write access comes with the read permission). MP3 and FLAC files can be written, by Orpheus's own tag
  editors, which change only the tags asked for and keep every other byte; other formats are read-only. A file
  another program changed since it was read is not written, and on Windows the track playing may be refused as in use.

### Changed

- On Windows and Linux the window opens maximized. Un-maximize it and close it, and the next launch opens it where you
  left it; maximize it again and it opens maximized again. The restore button goes back to the size you last gave it.
- The scan at startup reads again every track whose file changed since the last scan, so a title, artist or album
  corrected in a tag editor shows up everywhere the next time Orpheus starts — the library, the player, the queue's
  name and the statistics. It used to trust a folder that looked unchanged and keep the old tags until a scan was
  started by hand. The scan report says how many tracks were updated.
- A folder added or removed while a scan is running is scanned as soon as that scan finishes, instead of waiting for the
  next one.
- Orpheus is now released under the Artur Rios Attribution License instead of the MIT License. It stays free and open
  source; a copy, fork or product built on it credits the author with a link to artur-rios.tech or
  github.com/artur-rios. Releases up to 1.2.1 keep the licence they were published under.
- A beta on Windows or Linux is offered the next beta as well as the release it leads to; a full release is still only
  ever offered full releases. Versions are compared by full SemVer 2.0.0 precedence.
- Release process: a pre-release's `-beta.<n>` is now part of the `version:` in `pubspec.yaml` (`1.3.0-beta.1+7`), its
  packages are named with it (`orpheus-setup-1.3.0-beta.1.exe`), and the release workflow requires the tag to be
  exactly `v` followed by that version. See CONTRIBUTING.md, *Versioning*.

### Fixed

- Not now, Skip this version and Close on the update prompt close it. They used to empty it and leave the application
  dimmed behind an invisible dialog that swallowed the next click.
- The update prompt says Downloading while the download runs and Checking only while the download is being verified;
  the two were the other way round.
- On Android, playback pauses for a phone call and for another player taking over the sound, and resumes after the
  call only if it was playing before it.
- Choosing something that cannot start — a track with a saved position, or a record whose files are all missing —
  stops what was playing, rather than leaving it playing with no controls.
- A record whose last track is missing ends normally, or goes round again on Repeat all, instead of reporting that
  nothing in it could be played.
- A track resumed from past half way is not counted as a second play; starting a track again with Previous counts its
  replay; and a very short track heard to the end always counts.
- Statistics: tracks that share a title are ranked as separate tracks rather than added together; the story's share
  of plays is worked out over everything played rather than only the top ten; and tracks no longer in the library are
  not reported as untagged.
- A record or artist that is open in the library and gets renamed by a re-scan stays open under its new name.
- Removing a folder rescans the library again; the folder's tracks used to stay until the next scan.
- On Android, the back gesture no longer spends a press clearing a one-letter search that was not showing.
- A beta on Windows or Linux reported itself as the release it leads to (`1.3.0` for `v1.3.0-beta.1`), so it was
  never offered that release when it shipped.
- The Portuguese wording of counts is now correct when a count is zero: the unreadable-files line, the play counts in
  the rankings and on the story card, the story card's track count and the untagged-tracks note.
- A full scan no longer re-reads the tags of every track after a restart and reports the whole library as added.
  Files that have not changed are carried over, as they are within one session.
- A change made to a folder while a scan was running is picked up by the next startup scan, rather than kept out of
  the library until a full scan. A memory card or pen drive's coarse folder timestamps are allowed for as well.
- A registered folder that is there but cannot be read is reported as unreachable, with the same help on the Folders
  screen, instead of being scanned as empty and having its tracks removed from the library without a word.
- Choosing a track with a saved position while another one is playing offers the right position, and Resume resumes
  there; it used to drop to 0:00 a moment later and do nothing. The track that was playing ending meanwhile no longer
  starts the chosen one from the top before you answer.
- Two scans asked for at once — at startup and from a folder just added — no longer both run, and neither is left
  hanging.
- A `.lrc` file saved in an older single-byte encoding such as Latin-1 is read, instead of being passed over for the
  track's tags.
- A lyrics sheet you save beside a track while a looked-up one is being written is kept; the looked-up one is
  discarded.
- The Linux installer's per-user install goes to `~/.local` even when `XDG_DATA_HOME` is set. It used to put the
  launcher and the menu entry under `~/.local/share/bin` and `~/.local/share/share/applications`, where nothing finds
  them.
- The Windows installer no longer offers to remove "Orpheus" from a folder that only holds some other program's
  uninstaller.
- The lyrics lookup names the running version of Orpheus to the service, instead of always `1.0.0`.
- The album artist of a FLAC or Ogg file (`ALBUMARTIST`, or `ALBUM_ARTIST`) is read. A compilation tagged *Various
  Artists* used to be filed under whichever performer had the most tracks on it.
- A double record whose tracks are only partly tagged with a disc number no longer has its two discs' tracks
  interleaved: a track with no disc number is taken as disc 1.
- Playing an artist queues their records in the order the artist's page lists them.
- A cover left half-written by a scan that was interrupted is written again by the next scan, instead of staying cut
  short.
- A folder already registered is not added a second time under another spelling — another letter case on Windows, or a
  link to it.
- In a lyrics sheet that gives two lines the same time, such as an original and its translation, the lines keep the
  file's order and the first of them is lit.
- On Android, the notification and the lock screen no longer show the previous record's sleeve with a new track, and a
  track that stopped while the notification permission was being asked for is no longer posted afterwards as if it
  were playing.

### Security

- The in-app updater downloads into a new folder of its own rather than a predictable name in the shared temporary
  directory, so another account on the machine cannot plant or swap the installer that is checked and run.
- The in-app updater refuses an installer or a checksum list that is not served over HTTPS, and abandons a download
  that stops arriving instead of waiting for it indefinitely.
- The command the Linux updater hands over for a system-wide installation is quoted, so a path with a space in it
  still runs as written.

## [1.2.2-beta.1] - 2026-09-16

A pre-release built from the `diagnose/android-usb-folder` branch to diagnose folders on USB drives. It is not part of
`main`.

### Added

- A diagnostic panel on the Folders screen, shown only when a folder could not be reached. It reports what Android lets
  the application see at every level of the folder's path, with the error for each, and the storage volumes visible to
  it. It is deliberately raw and not translated, and is meant to come out again once it has done its job.

## [1.2.1] - 2026-09-10

### Changed

- On Android, when a folder on a memory card or USB drive is still unreachable after all-files access has been
  granted, the Folders screen now says what is left to try: close Orpheus and open it again with the drive in place.

## [1.2.0] - 2026-09-10

### Added

- Android can read a library on a memory card or a drive plugged into the phone. When a registered folder turns out
  to be unreachable, the Folders screen explains why and offers all-files access, which is asked for at that moment
  only.
- A track name too long for the playback bar slides so the whole of it can be read. With reduced motion turned on in
  the system it stays still and is cut short as before.

### Fixed

- The previous-track button is back on the phone playback bar.
- A second or later scan in the same session no longer stays on "scanning" forever.
- The Android playback notification draws its icon, stays available while paused so play resumes from it, and is no
  longer lost when audio focus cannot be arranged.
- An unplayable file is skipped once, instead of several error lines each skipping a track and sometimes emptying the
  queue.

## [1.1.0] - 2026-09-08

### Added

- The Windows and Linux builds check for a newer release at startup and offer it. Accepting downloads the installer,
  verifies it against the release's `SHA256SUMS.txt`, and runs it; a Linux install under a system prefix gets the
  `sudo` command to run instead. On by default, and turned off under *Updates* in the preferences. Not on Android.
- A story view of the listening statistics, one fact per card, where any card can be shared or saved as a picture.

## [1.0.1] - 2026-09-08

### Fixed

- The Android package is signed with the project's own release key instead of a per-build debug key, so later releases
  install as updates. Coming from 1.0.0, which was signed with a throwaway key, Android needs the application
  uninstalled first, and that removes the library, statistics and settings.
- On a phone, the music area's view switcher gets a row of its own instead of wrapping its labels mid-word.
- Closing the application on Windows hides the window at once instead of leaving it on screen while it shuts down.

## [1.0.0] - 2026-09-07

### Added

- A library read from the folders you register: a scan reads the tags (ID3, Vorbis comments, iTunes atoms, RIFF, APE)
  and cover art of every audio file, and the catalog is kept beside the application's settings.
- Browsing by artist, album and song, in rows or as sleeves, and search across titles, artists and albums.
- Playback of a track, a record, an artist or the whole library shuffled, with a visible queue, repeat, a resume point
  per track, a persistent playback bar and a full player. A file that will not play is named and stepped over.
- Background playback on Android, controlled from the notification and the lock screen, pausing for a phone call and
  for unplugged headphones.
- Listening statistics: total plays and the most played tracks, artists, records and genres.
- Sound bars drawn from the recording's own spectrum.
- Synced lyrics from a `.lrc` beside the track or from the track's own tags, with an optional online lookup that saves
  the words as a `.lrc` beside the track.
- Light and dark themes, in English and Brazilian Portuguese.
- Release downloads: a Windows installer, a portable Windows archive, a Linux installer and an Android APK, with
  `SHA256SUMS.txt`.

[Unreleased]: https://github.com/artur-rios/orpheus/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/artur-rios/orpheus/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/artur-rios/orpheus/compare/v1.2.1...v1.3.0
[1.2.2-beta.1]: https://github.com/artur-rios/orpheus/compare/v1.2.1...v1.2.2-beta.1
[1.2.1]: https://github.com/artur-rios/orpheus/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/artur-rios/orpheus/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/artur-rios/orpheus/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/artur-rios/orpheus/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/artur-rios/orpheus/releases/tag/v1.0.0
