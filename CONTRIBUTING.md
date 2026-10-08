# Contributing

The normative rules for how work is delivered — branches, commits, the issue lifecycle, pull requests and the
Definition of Done — are in the
[Development Workflow Document](./docs/requirements/Development%20Workflow%20Document.md), and the tests are specified
in the [Testing Specification Document](./docs/requirements/Testing%20Specification%20Document.md). This file collects
what you need to build, test and release the application.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.47.2, stable channel — the version the project is built
  and tested against (see the [Technology Stack Document](./docs/requirements/Technology%20Stack%20Document.md)).
- **Linux:** `ninja-build` and `libgtk-3-dev` to build, and libmpv to play (`sudo apt install libmpv-dev mpv` on
  Debian and Ubuntu).
- **Android:** a JDK 17 and the Android SDK.
- **Windows:** the MSVC toolchain Flutter's Windows build needs, and [Inno Setup](https://jrsoftware.org/isdl.php)
  for the installer.
- **The icon:** Python 3 with Pillow.

## Layout

```
lib/
  core/            themes, spacing, breakpoints, settings, failures, l10n,
                   and the single composition root in core/di/providers.dart
  features/
    library/       folders, scanning, tags, cover and catalog storage
    playback/      the queue, the engine and media-session boundaries, and
                   the music area
    lyrics/        finding a track's words on this machine, and reading along
    stats/         the play threshold, the history, and the rankings
    shell/         the frame: navigation, the playback bar, preferences

tools/             dev.sh / dev.ps1 to run it, verify.sh / verify.ps1 to
                   check it, and the two installer builds
packaging/windows/ the Inno Setup script the installer is compiled from
packaging/linux/   the shell installer the Linux payload is wrapped in
packaging/icon/    the application icon, and the script that draws it
```

Each feature is `domain` (no Flutter, no IO), `data` (the outward edges),
`application` (the controllers), `presentation` (the widgets). Nothing outward
is constructed anywhere but `core/di/providers.dart`, which is what lets a test
override a binding rather than patching a global.

## Building and testing

```bash
flutter analyze              # must be clean; there is no known-warnings list
flutter test                 # the unit and widget suite
flutter build linux --release
flutter build windows --release
flutter build apk --release
```

### Tests

Tests are named Given-When-Then, one behaviour apiece, and follow the source
tree: `lib/x/y.dart` is tested by `test/x/y_test.dart`. Nothing in the suite
reads the developer's own preferences, writes into their application-support
folder, records against their listening statistics, opens the native playback
engine, starts a platform media service, or reaches the network — every one of
those is a provider, and every one is overridden by the harness in
`test/support/test_container.dart`.

Two of the tests are guards rather than assertions about behaviour, and they
exist because a rule nobody checks is a comment:

- `test/core/theme/no_colour_literal_test.dart` — every colour comes from the
  theme's single seed, and nothing outside `lib/core/theme/` may declare one.
- `test/core/l10n/catalog_parity_test.dart` — both languages stay complete, every
  message carries a description, and a translation uses the same placeholders as
  its original.

The scanner and the tag reader are tested against real files in a temporary
directory, built by `test/support/flac_fixture.dart` — a genuine FLAC header
with real Vorbis comments and a real embedded picture, small enough to write
from a test.

### Running it while you work on it

```bash
./tools/dev.sh               # Linux and macOS
.\tools\dev.ps1              # Windows
```

Picks a device, checks what it needs, and starts the application. With no
arguments it runs on this host's desktop; with one device attached and no
desktop target, on that one; with several, it refuses and lists them rather
than guessing — being handed a phone when you meant the desktop costs more time
than typing `--device`.

**The loop is Flutter's own.** While it runs, `r` hot-reloads, `R` hot-restarts,
`q` quits — so *change the code and see it* is one keystroke, not another run of
the script. Start it again for the things hot reload cannot carry: a new
dependency, a native or platform file, or a change to either `.arb` catalog
(then use `--generate`).

| Flag | |
| --- | --- |
| `--device ID` / `--android` | Where to run. `--android` takes the attached device or emulator, whatever its id. |
| `--clean` | Delete this application's own data — the catalog, cover cache, analysed spectra, play history and preferences — so the next start is a first launch. **Never touches your music**, names exactly what it will delete, and asks first unless `--yes`. On Android it clears the app's data on the device. |
| `--generate` | Regenerate the localizations first. |
| `--test` | Run the suite first, and stop if it is red. |
| `--profile` / `--release` | Run the way an owner would get it. Neither has hot reload — that is debug only, and the script says so rather than letting you press `r` into silence. |
| `--no-run` | Do everything else and stop. |

On Linux it also checks for libmpv up front, because without it playback fails
at the first press of play rather than at startup — which is a long way from the
cause.

On Windows the first build in a fresh build directory prints `Nuget.exe not
found, trying to download or use cached version.` That is CMake, not this
application: `permission_handler_windows` compiles against the CppWinRT NuGet
package and fetches a pinned, checksummed `nuget.exe` when one is not on `PATH`.
It is a status line rather than a warning — a real failure stops the build with
`Failed to install nuget package Microsoft.Windows.CppWinRT` — and it prints
once per clean build directory. `winget install Microsoft.NuGet` silences it.
The plugin itself does nothing on Windows; it arrives as the endorsed Windows
implementation of the `permission_handler` that Android needs, and Flutter
builds every plugin registered for a platform whether or not it is used.

`tools/dev.ps1` takes the same flags in long form (`-Device`, `-Clean`, `-Yes`).

### The icon

The application icon is a lyre — Orpheus's own instrument — whose strings are
the sound bars from the player screen, standing at the uneven heights a level
meter stands at.

It is **drawn in code**, not kept as a binary nobody can edit: a change to the
palette, the proportions or the string heights is a diff in one Python file,
and every size every platform wants is regenerated from it.

```bash
python3 packaging/icon/make_icon.py     # needs Pillow, and nothing else
```

That writes the Android launcher icons at all five densities — the square one
for releases before Android 8, and the adaptive icon's foreground layer, drawn
without its background so the launcher can mask the pair into whatever shape
the device uses — the Windows `.ico`, the Linux window icon, and the 1024px
master in `packaging/icon/`.

The two smallest `.ico` frames are drawn from **separate, simpler artwork**.
At sixteen and thirty-two pixels the arms and the yoke are a stroke under two
pixels wide, which is not a lyre, it is grey fringing; what those frames show
instead is what the mark is about — three bars at three heights on their
soundbox. An `.ico` saved from one image is that image downsampled six times,
and the two smallest of those are the mush this avoids.

Flutter's Linux runner ships no icon at all, so `linux/CMakeLists.txt` installs
the PNG beside the bundle's data and `my_application.cc` loads it into the
window. Beside the bundle rather than into a `hicolor` theme deliberately: this
is the icon of the window this binary opens, which is a different thing from
the icon a packaged application registers with the desktop, and only the first
is the build's to decide.

### Verifying everything at once

```bash
./tools/verify.sh            # Linux and macOS
.\tools\verify.ps1           # Windows
```

Each runs the analyzer, the suite, and a release build of every target its host
can build — then prints one summary saying what passed, what was skipped, and
what this operating system could never have done in the first place.

That last distinction is the point of the script. **No single machine can build
all three targets**: Windows binaries need Windows and MSVC, Linux binaries need
Linux and GTK. So a run reports three outcomes rather than two —

| | Meaning | Under `--strict` |
| --- | --- | --- |
| `PASS` | It ran and it passed. | passes |
| `SKIP` | A toolchain that could have been here was not — no Android SDK, no `libgtk-3-dev`. | **fails** |
| `n/a` | This operating system cannot build that target at all. | passes |

— because a missing Android SDK is something you can fix, and a Linux machine
not producing a Windows binary is not.

Useful flags: `--no-build` for the fast loop, `--only linux|android|windows` for
one target, `--strict` for CI. `tools/verify.ps1` takes the same ones in long
form, plus `-Installer`.

`.github/workflows/verify.yml` is what makes the `n/a` rows add up to nothing: it
runs `verify.sh --strict` on Linux (Linux + Android) and `verify.ps1 -Strict` on
Windows (Windows + the installer). It also reads the built APK's permissions back
out and **fails the build if they are not exactly the eight declared in
`AndroidManifest.xml`** — which is the promise at the top of the README,
enforced rather than asserted. A deny list would only catch the permissions
somebody thought to forbid; pinning the whole set catches the next one
whatever it is, including one merged in by a dependency.

### The Windows installer

```powershell
.\tools\build-windows-installer.ps1
```

Builds the Windows release and compiles `packaging\windows\installer.iss` into
`dist\orpheus-setup-<version>.exe`. It needs [Inno Setup](https://jrsoftware.org/isdl.php)
(`winget install JRSoftware.InnoSetup`); the script looks for `ISCC.exe` on
`PATH` and in both standard install directories, and takes `-InnoSetupPath` if
it is somewhere else. `-SkipBuild` reuses an existing release build.

Every push to `develop` or `main`, and every pull request into them, builds it:
the `Verify` workflow's Windows job uploads `orpheus-setup-<version>.exe` as an
artifact, so the latest one is a download away from the run that produced it.

### The Linux installer

```sh
./tools/build-linux-installer.sh
```

Builds the Linux release and wraps it in `dist/orpheus-installer-<version>.sh`
— a shell script with the release bundle compressed onto the end of it.
`--skip-build` reuses an existing release build.

A self-extracting script rather than a `.deb`, a Flatpak or an AppImage, and
the reason is what each of those assumes. A `.deb` assumes `apt`, which leaves
out every distribution that does not use it. A Flatpak assumes Flatpak is set
up, and adds a sandbox that would have to be punched through for the one thing
this application does — read music folders the owner chose, anywhere on their
disk. An AppImage is a portable binary rather than an installation: no launcher
entry, no icon.

What the installer does once built is described under
[Downloads](./README.md#downloads) in the README.

## Branching and pull requests

```
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main  (tag vx.y.z)
```

| Branch | Cut from | Merges into | How |
| --- | --- | --- | --- |
| `feature/<name>`, `fix/<name>` | `develop` | `develop` | Pull request, squash or merge. The branch is deleted on merge. |
| `release/x.y.z` | `develop` | `main` | Pull request, merge commit. Carries no commits of its own. |
| `develop`, `main` | — | — | Protected: no direct pushes, no force pushes, no deletion. |

`develop` is the default branch, and nothing is committed to it or to `main` directly. One branch per issue, named
`feature/uc-<number>-<short-name>` — e.g. `feature/uc-14-resume-a-track`. Work that is not a use case takes the same
pattern without the `uc-` segment, and a defect fix takes `fix/`: `fix/scan-progress-strip`. Names are lowercase:
letters, digits, `.`, `_` and `-`. A `release/` branch is a snapshot of `develop`: a fix for a release lands on
`develop` through a `fix/` branch and a new release branch is cut.

The **Branch Policy** workflow (`.github/workflows/branch-policy.yml`) checks all of this on every pull request into
`develop` or `main`. It, and both jobs of the `Verify` workflow, are required checks on both branches. The repository
owner can bypass these rules; that is for emergencies, not for routine work.

A pull request is titled after the use case (`UC-14 — Resume a track where it stopped`), says what was built, which
flows and alternative flows are covered and what was deliberately left out, and links its issue so merging closes it.
Nothing is merged with a failing analyzer or a failing suite. The full rules, and the Definition of Done, are in the
[Development Workflow Document](./docs/requirements/Development%20Workflow%20Document.md).

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/), all lower case, subject in the
imperative mood and no longer than 50 characters including the type prefix, e.g.
`feat: play in the background on android` or `fix: let go of a finished scan, so the next one runs`. The commit type
is any of `feat`, `fix`, `refactor`, `docs`, `build`, `chore`, `test`, `ci` or `perf`, whatever the branch is called.

Record every change an owner would notice under `## [Unreleased]` in [CHANGELOG.md](./CHANGELOG.md), in the same
pull request that makes it.

## Versioning

Orpheus follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html), tagged `v<major>.<minor>.<patch>`. For an
application, what a version number promises is about the owner who installed it: what it does on screen, the
library, catalog, statistics and settings it keeps between runs, and whether the next release installs over the one
they have.

- **Major** — a release that breaks something an owner relies on. A feature is removed, or works so differently
  that it has to be relearned; the catalog, the play history or the preferences a previous version wrote are no
  longer read, so a library has to be registered and scanned again or statistics start from nothing; or the
  release cannot be installed over the previous one, drops a platform, or raises the minimum Android release.
  Its entry in [CHANGELOG.md](./CHANGELOG.md) carries an `### Upgrading from <X>.x to <Y>.0` section saying what to
  do.
- **Minor** — something an owner can do that they could not before, leaving everything they already did working as
  it did.
- **Patch** — a fix, or a screen saying something truer.

A pre-release carries a SemVer pre-release identifier, `-beta.<n>`: `v1.3.0-beta.1` is a pre-release of `1.3.0`, comes
before it, and is published as a GitHub pre-release. The in-application update check orders versions by SemVer 2.0.0
precedence — `1.3.0-beta.1` < `1.3.0-beta.2` < `1.3.0`, build metadata ignored. A stable build asks GitHub for the
latest *release*, which is never a pre-release, so nobody is offered one who did not go looking for it. A build that is
itself a pre-release reads the release list instead and is offered the highest version on it: the next beta, then the
release it leads to.

The version lives in one place, the `version:` in `pubspec.yaml`, as `<major>.<minor>.<patch>+<build>`, or
`<major>.<minor>.<patch>-beta.<n>+<build>` for a pre-release: `v1.3.0-beta.1` is built from `1.3.0-beta.1+7`. Both
installer scripts read it from there, so their file names carry the pre-release (`orpheus-setup-1.3.0-beta.1.exe`);
Flutter compiles it into the application, which is how a beta knows it is one — built from `1.3.0+7`, it would report
itself as `1.3.0` and never be offered the `1.3.0` that follows it; and the release workflow refuses a tag that is not
`v` followed by that version, pre-release included and build number left out. The build number rises with every
package that is published, pre-releases included, because Android reads it as `versionCode` — through
`flutter.versionCode` in `android/app/build.gradle.kts` — and an update whose code did not rise is not an update as far
as the platform is concerned.

**The next release's build number must be 7 or higher.** `pubspec.yaml` on `main` says `1.2.1+5`, but `v1.2.2-beta.1` shipped an APK
built as `1.2.2+6` from the `diagnose/android-usb-folder` branch, and a phone that installed it holds `versionCode`
6.

## Releasing

A release branch carries no commits of its own, so everything a release changes in the repository lands on `develop`
first, through a normal branch and pull request — `feature/release-1.3.0`, say, with a `chore: release 1.3.0`
commit:

- `version:` in `pubspec.yaml` set to the new version — with its `-beta.<n>` for a pre-release — and the next build
  number;
- `## [Unreleased]` in [CHANGELOG.md](./CHANGELOG.md) renamed to `## [<version>] - <yyyy-mm-dd>` above a fresh,
  empty `## [Unreleased]`, and the compare links at the bottom updated.

Then:

1. Cut the release branch from `develop` and push it:

   ```sh
   git switch develop && git pull
   git switch -c release/1.3.0
   git push -u origin release/1.3.0
   ```

2. Open a pull request `release/1.3.0 → main`. The Branch Policy check refuses it if the branch carries a commit that
   is not on `develop`, or if `v1.3.0` is already tagged.
3. When the checks pass, merge it with a merge commit, and delete the release branch.
4. Tag the merge commit on `main` and push the tag — only the repository owner can create a `v*` tag:

   ```sh
   git switch main && git pull
   git tag v1.3.0
   git push origin v1.3.0
   ```

A pre-release goes the same way — `release/1.3.0`, with `pubspec.yaml` saying `1.3.0-beta.1+<build>` — and is tagged
`v1.3.0-beta.1` on the merge commit instead. The next beta, or the stable release that follows, is a new package:
`pubspec.yaml` says `1.3.0-beta.2+<build>` or `1.3.0+<build>`, with a higher build number, so it goes through `develop`
and a release branch again.

`.github/workflows/release.yml` does the rest. It refuses immediately if the tagged commit is not on `main` — so a
build from any other branch is never published as a release; `v1.2.2-beta.1` predates the rule — or if the tag is not
`v` followed by the version in `pubspec.yaml`, pre-release included — a release whose file names, installer wizard and
application each state something different is worth failing a job over.

Then four artifacts, each built where it can be — the Windows installer, the
portable Windows archive, the Linux installer and the APK, listed under
[Downloads](./README.md#downloads) in the README.

The APK is put through the same permission gate the Verify workflow applies,
against the package that actually ships, and the same is done with its signer
— see below. The analyzer and the suite are run before anything is built,
because a release is not the place to discover the suite is red. Every file is
checksummed into `SHA256SUMS.txt`, which is the only way somebody can tell that
what they downloaded is what the workflow built — both desktop installers are
unsigned.

The workflow can also be run by hand from the Actions tab, naming an existing
tag to build a release from.

### The Android signing key

Android refuses to install an update whose signer changed. A package signed
with the debug key would therefore be a package nobody can upgrade to: the
runner generates a fresh debug key per run, so every release would carry a
different signer, and an owner would meet the next one as *App not installed*
with no way forward but uninstalling — losing the library, the statistics and
the settings that an upgrade is supposed to keep.

So the release workflow signs with a key the project holds, and refuses to
build without one.

**1. Make the keystore.** Once, and never again. `keytool` ships with the JDK
that Android Studio installed, so it is already on your machine.

On Windows, in PowerShell:

```powershell
keytool -genkeypair -v -keystore orpheus-release.jks -alias orpheus `
  -keyalg RSA -keysize 4096 -validity 10000 -storetype pkcs12
```

On Linux or macOS:

```sh
keytool -genkeypair -v -keystore orpheus-release.jks -alias orpheus \
  -keyalg RSA -keysize 4096 -validity 10000 -storetype pkcs12
```

It asks for a password, then for a name, an organisation and a country. None of
those answers are checked by anything or shown to anyone; the password is the
part that matters. **Write the password down before you press enter** — there is
no way to recover it and no way to replace the keystore later.

**2. Encode it.** The secret holds the file's bytes as text, because a GitHub
secret is a string.

On Windows, which has no `base64` command — this writes the file and puts the
same text on your clipboard, ready to paste:

```powershell
$encoded = [Convert]::ToBase64String([IO.File]::ReadAllBytes("orpheus-release.jks"))
$encoded | Set-Content -NoNewline keystore.base64.txt
$encoded | Set-Clipboard
```

On Linux or macOS:

```sh
base64 -w0 orpheus-release.jks > keystore.base64.txt
```

Not `certutil -encode`: it wraps its output in `-----BEGIN CERTIFICATE-----`
lines, which are not part of the data and will not decode.

**3. Put four secrets in the repository.** *Settings → Secrets and variables →
Actions → New repository secret*. The names are case-sensitive and must be
exactly these:

| Secret | What to paste into it |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The entire contents of `keystore.base64.txt` — one long run of letters, digits, `+` and `/`, possibly ending in `=`. Paste what step 2 put on the clipboard, or open the file and select all. Not the `.jks` itself: a secret is text. Line breaks in it are harmless, the workflow strips them. |
| `ANDROID_KEYSTORE_PASSWORD` | The password you typed at *Enter keystore password*. |
| `ANDROID_KEY_ALIAS` | `orpheus` — whatever followed `-alias` in the command above. |
| `ANDROID_KEY_PASSWORD` | **The same password again.** A PKCS12 keystore holds one password for both; keytool warns and ignores a `-keypass` that differs from the store password, so there is no second password to give. |

Then delete `keystore.base64.txt` — it is the keystore in another form, sitting
in the repository directory. `.gitignore` refuses to commit it, and the `.jks`
beside it, but neither belongs there once the secret is set.

**Back the `.jks` up somewhere that is not this machine, and keep the
passwords.** Losing it cannot be undone by generating another: every owner who
installed a release signed with the old one would have to uninstall first, and
their catalog, statistics and settings would go with it. It is the one file in
this project that has no copy in the repository and cannot be rebuilt from it.

**4. Optional, once the first signed release is out.** Read its fingerprint out
of the workflow log — the *Read the signer back out of the package* step prints
`Signed with SHA-256 <64 hex characters>` — and set it under *Variables*, not
*Secrets*, as `ANDROID_SIGNING_SHA256`. From then on a release signed by
anything else fails the job instead of shipping an update nobody can install.

Building a signed package locally needs none of that. `flutter build apk
--release` with no key configured falls back to the debug key and works as it
always did — that is only ever a package for your own device. To sign locally,
put `android/key.properties` beside the module, which `android/.gitignore`
already refuses to commit:

```properties
storeFile=../orpheus-release.jks
storePassword=...
keyAlias=orpheus
keyPassword=...
```
