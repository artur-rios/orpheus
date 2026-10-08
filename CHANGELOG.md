# Changelog

All notable changes to Orpheus are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- A beta on Windows or Linux is offered the next beta as well as the release it leads to; a full release is still only
  ever offered full releases. Versions are compared by full SemVer 2.0.0 precedence.
- Release process: a pre-release's `-beta.<n>` is now part of the `version:` in `pubspec.yaml` (`1.3.0-beta.1+7`), its
  packages are named with it (`orpheus-setup-1.3.0-beta.1.exe`), and the release workflow requires the tag to be
  exactly `v` followed by that version. See CONTRIBUTING.md, *Versioning*.

### Fixed

- A beta on Windows or Linux reported itself as the release it leads to (`1.3.0` for `v1.3.0-beta.1`), so it was
  never offered that release when it shipped.

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

[Unreleased]: https://github.com/artur-rios/orpheus/compare/v1.2.1...HEAD
[1.2.2-beta.1]: https://github.com/artur-rios/orpheus/compare/v1.2.1...v1.2.2-beta.1
[1.2.1]: https://github.com/artur-rios/orpheus/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/artur-rios/orpheus/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/artur-rios/orpheus/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/artur-rios/orpheus/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/artur-rios/orpheus/releases/tag/v1.0.0
