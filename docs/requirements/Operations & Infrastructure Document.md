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
nothing at all is written into the owner's music folders (`BR-02`).

| What | Where |
| --- | --- |
| Catalog | `catalog.json` |
| Play history | `play-history.json` |
| Cover cache | `covers/` |
| Preferences | the platform's own preference store |

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

**IR-13** — The package declares **no `INTERNET` permission**, and this is
verifiable from the built package. It is the enforceable form of `BR-03` and
`NFR-02`, and a change that adds one is a change that breaks the product's
stated promise.

**IR-14** — The single activity extends the playback service's own activity, so
that the service and the interface share one Flutter engine. With two, the queue
on screen and the queue in the notification would be two different players.

## 6. Logging

**IR-15** — One logger per feature area — `library`, `playback`, `stats`,
`shell`, `startup` — initialized at startup. Logging is local and structured. No
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
and fails if `INTERNET` appears among them. This is `BR-03` and `NFR-02` made
enforceable: asserted against the artifact that ships, not against the source.

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
