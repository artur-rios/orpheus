# Operations & Infrastructure Document — Orpheus

Platform and operational requirements, `IR-xx`. These are the cross-cutting
concerns every use case is built on, and together they are the scope of the
foundation issue (M-01).

## 1. Project layout

**IR-01** — The source is laid out by feature, and each feature by layer.

```
lib/
  core/            themes, spacing, breakpoints, settings, failures, l10n,
                   platform detection, logging, and the single composition
                   root in core/di/providers.dart
  features/
    library/       folders, scanning, tags, cover and catalog storage
    playback/      the queue, the engine and media-session boundaries,
                   and the music area
    stats/         the play threshold, the history, and the rankings
    shell/         the frame: navigation, the playback bar, preferences
```

**IR-02** — Each feature is `domain` (no Flutter, no IO), `data` (the outward
edges), `application` (the controllers) and `presentation` (the widgets).

**IR-03** — A layer never imports a layer outward of itself. `domain` imports
nothing from the other three.

**IR-04** — Every outward dependency is constructed in `core/di/providers.dart`
and nowhere else. This is what lets a test override a binding rather than
patching a global, and it is the mechanism behind `NFR-07` and `NFR-08`.

## 2. Where the application writes

**IR-05** — Everything this application persists lives inside the platform's
application-support directory for it. Nothing is written anywhere else, and
the only things written into the owner's music folders are a `.lrc` beside a track whose words were looked up (`BR-29a`), and the tags of files whose autofill the owner confirmed (`FR-AF-05`). The one other file it writes is a playlist the owner exports, to the place they chose (`FR-PS-11`).

| What | Where |
| --- | --- |
| Catalog | `catalog.json` |
| Play history | `play-history.json` (version 2: each play dated for 90 days), a `play-history.json.v1` copy of a version-1 document made once when it is first read, and a `play-history.json.bad-<time>` for a document that could not be read, or a copy of one that was partly read |
| Playlists | `playlists.json`, and a `playlists.json.bad-<time>` for one that could not be read |
| Playlist covers | `playlist-covers/` |
| Cover cache | `covers/` |
| Analysed spectra | `energy/` |
| Preferences | the platform's own preference store |

The two auto playlists have no row: they are worked out from the play history and the catalog each time and are never
written (`FR-PS-14`). The `.v1` and `.bad-` files are the owner's to keep or delete; Orpheus never reads
them again, and the `.v1` copy is made once, never over an earlier one.

Both caches are disposable: deleting `covers/` or `energy/` costs the work of
building them again and nothing else. They are directories of plain files, and
they are kept apart from each other so that either can be deleted on its own, by
the owner, without this application's help.

**IR-06** — Documents are versioned and written atomically: to a temporary file,
then renamed over the real one. A document written by an incompatible version is
discarded rather than partially read.

## 3. Startup

**IR-07** — Startup resolves, in order: logging, the preference store, the
application directories, the desktop window where there is one, and the platform
media session where there is one. Only then is the interface shown.

**IR-08** — Startup is never gated on a scan (`NFR-04`). The library from the
last scan is on screen first; a new scan starts after the first frame and
reports from a strip above the playback bar.

**IR-09** — A preference store that cannot be read is not fatal. The application
opens at its defaults and says so, and the owner's next choice is what gets
recorded.

**IR-10** — A media session that cannot be started is not fatal. The application
opens and plays; only background playback is lost, and the reason is logged
(`FR-BG-10`).

## 4. Platform detection

**IR-11** — Which platform is running is read through one seam, never from
`Platform` at a call site. Three decisions turn on it — whether to manage a
window, whether to ask for a storage permission, and which folders a first
launch offers — and each must be overridable in a test that runs on whatever the
developer happens to have.

## 5. Android

**IR-12** — The package declares exactly these permissions, and no others:

| Permission | For |
| --- | --- |
| `READ_MEDIA_AUDIO` | Reading the owner's audio files on Android 13 and later. |
| `READ_EXTERNAL_STORAGE`, capped at API 32 | The same, on releases predating the per-media split. |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Playback that continues off screen. |
| `POST_NOTIFICATIONS` | The playback notification. |
| `WAKE_LOCK` | Keeping the processor running through a track with the screen off. |
| `MANAGE_EXTERNAL_STORAGE` | A registered folder on a memory card or a drive plugged into the phone; and, on Android 11 and later, changing the tags of files whose autofill the owner confirmed. |
| `WRITE_EXTERNAL_STORAGE`, capped at API 29 | Changing the tags of files whose autofill the owner confirmed, on Android 10 and earlier. On Android 7 to 10 it is granted together with read access, in the same system dialog, and is only ever used for an autofill the owner confirmed (`FR-AF-08`). |

`MANAGE_EXTERNAL_STORAGE` is the broad one, and it is bounded by when it is asked for
rather than by its own scope: Android mounts removable volumes outside the
storage `READ_MEDIA_AUDIO` covers and offers no narrower permission for them,
so a folder on one is unreadable until this is granted. It is never requested
on a launch, never on a scan, and never on the way into a folder picker — only
once a folder the owner registered has been walked and reported unreachable,
and then from a card on the folders screen that says what it allows. The one
other moment is on Android 11 and later, at the first autofill the owner
confirms, when the application is about to change the tags of files it did not
make (`FR-AF-08`); it is not asked for before that confirmation. On Android 7
to 10 there is no such moment of its own: Android grants
`WRITE_EXTERNAL_STORAGE` together with read access, in the same system dialog
the library's first scan raises, and the application uses it only for an
autofill the owner confirmed. Granting it widens
nothing about what the application does: the folders walked are the folders
registered, the only thing written is the tags the owner confirmed (`BR-02`),
and `BR-03` is unchanged.

Granting it is also not always enough within the run that asked. Android fixes
a process's view of the mounted volumes when the process starts, so a volume
mounted after that — and, on the devices that do not remount a running
application, the permission itself granted after that — is outside the view
the run holds, and the folder stays unreachable until the next launch. The
folders screen therefore has a second card, shown where the permission is
already granted and a folder is still unreachable, and what it asks for is the
next launch rather than a permission there is nothing left to grant.

**IR-13** — The package declares **`INTERNET`, and only for the lyrics lookup and the
autofill lookup** (`BR-29a`, `FR-LY-13`, `FR-AF-02`). The manifest says so at the declaration, in terms of
what is sent and what is not. The enforceable form of `BR-03` and `NFR-02` is
no longer the absence of that permission but the exactness of the whole set:
the built package must declare the permissions the manifest lists and no
others, so a network capability arriving through a dependency fails the build
rather than shipping quietly. A change that adds a permission is a change that
must be argued for in the manifest, in the README, and here, first.

**IR-14** — The single activity extends the playback service's own activity, so
that the service and the interface share one Flutter engine. With two, the queue
on screen and the queue in the notification would be two different players.

## 6. Logging

**IR-15** — One logger per feature area — `library`, `playback`, `lyrics`,
`autofill`, `stats`, `shell`, `startup` — initialized at startup. Logging is local and structured. No
log leaves the machine (`BR-03`).

**IR-16** — A failure that the owner can do something about is surfaced in the
interface; a failure they cannot is logged. Nothing is silently swallowed except
where a documented rule says otherwise, and there is exactly one such rule:
recording a play (`BR-22`, `FR-ST-04`).

## 7. Build and release

**IR-17** — All three targets build from the same source with no per-platform
source set above the platform edges:

```bash
flutter build linux --release
flutter build windows --release
flutter build apk --release
```

**IR-18** — Running the application while working on it is a script, not a
remembered sequence: `tools/dev.sh` on Linux and macOS, `tools/dev.ps1` on
Windows. Each picks a device, checks what that platform needs at runtime, and
starts the application; the edit-and-see-it loop itself is Flutter's own hot
reload rather than anything this project reimplements. `--clean` resets the
application to a first launch by deleting what it wrote, and never touches the
owner's music — it names what it will delete and asks first.

**IR-19** — Verification is a script, not a remembered sequence: `tools/verify.sh`
on Linux and macOS, `tools/verify.ps1` on Windows. Each runs the analyzer, the
suite, and a release build of every target its host can build, and reports three
outcomes rather than two — passed, skipped, and not applicable. A toolchain that
could have been present and was not is a **skip**, and fails under `--strict`. A
target the host's operating system cannot produce at all is **not applicable**,
and never fails: no configuration makes a Linux machine emit a Windows binary.

**IR-20** — Because no single host can build every target, the claim is only
complete across hosts. `.github/workflows/verify.yml` runs the same two scripts
on a Linux runner and a Windows runner, so that every target is built and every
"not applicable" is covered somewhere.

**IR-21** — The workflow reads the built Android package's permissions back out
and fails unless they are exactly the set `AndroidManifest.xml` declares. This
is `BR-03` and `NFR-02` made enforceable: asserted against the artifact that
ships, not against the source, and against the merged manifest rather than the
one in this repository — which is where a dependency's own permission would
otherwise appear unannounced.

**IR-22** — Neither a failing analyzer nor a failing test suite may be released.

**IR-23** — The Windows installer is produced by Inno Setup from
`packaging/windows/installer.iss`, driven by `tools/build-windows-installer.ps1`,
and lands in `dist/`. It installs per-machine or per-user, upgrades by removing
the previous installation first — including one left in another directory — and
its removal is targeted at the files the payload writes rather than the
directory, which the owner may have chosen by hand.

**IR-24** — Installing, upgrading and uninstalling never touch the catalog, the
cover cache, the play history or the settings. An uninstall is not a request to
forget what the owner listened to.

**IR-25** — The installer is unsigned, and this is a deliberate deferral rather
than an oversight: code signing needs a certificate the project does not hold.
Until it does, SmartScreen warns on first run, and the README says so.

**IR-26** — The Linux build requires `libmpv` at runtime on the target machine.
This is stated in the README rather than bundled, because bundling libmpv is a
licensing and packaging decision this project has not made.

## 8. Accessibility and presentation

**IR-27** — Interactive controls carry labels, and the reduced-motion setting is
honoured. The reduced-motion path is the one the widget tests exercise, so it is
the path that stays correct.

**IR-28** — The arrangement follows window width at every size, not the
operating system (`BR-28`).
