---
title: Downloads
linkTitle: Downloads
weight: 40
description: The current release, for each platform.
---

{{< orpheus/downloads >}}

## Before you install

**Both installers are unsigned.** Windows SmartScreen will warn the first time
you run the setup executable, and Android will ask you to allow installing from
this source. That is what an unsigned binary looks like, and it will keep
looking like that until the project holds a code-signing certificate.

**Check what you downloaded.** Every release carries a `SHA256SUMS.txt`. It is
the only way to tell that the file you have is the file CI built:

```sh
sha256sum -c SHA256SUMS.txt
```

```powershell
# Windows
Get-FileHash .\orpheus-setup-1.0.0.exe -Algorithm SHA256
```

## What each one is

### Windows — installer

A normal setup executable. It offers a per-machine or a per-user install, a
Start menu entry and an optional desktop icon, and it registers an uninstaller
in *Add or remove programs*.

Upgrading over an existing installation removes the old one first rather than
layering over it — a stale engine library left beside a new binary surfaces
later as an unrelated-looking failure to start playback.

### Windows — portable

Unpack it anywhere and run `orpheus.exe`. Nothing is installed and nothing is
written to the registry; it runs from a memory stick.

{{% alert title="Why it is an archive and not a single .exe" color="info" %}}
A Flutter Windows application is an executable sitting beside the playback
engine's DLLs and a `data` directory, and it does not run without them. A single
self-contained `.exe` would have to be a self-extracting wrapper that unpacks to
a temporary directory on every launch — which is slower, and makes the unsigned
binary look more suspicious to antivirus, not less.
{{% /alert %}}

### Linux — installer

A shell script with the release bundle compressed onto the end of it.

```sh
chmod +x orpheus-installer-1.0.0.sh

./orpheus-installer-1.0.0.sh              # just for you, under ~/.local
./orpheus-installer-1.0.0.sh --system     # for everyone, under /usr/local
./orpheus-installer-1.0.0.sh --prefix DIR # somewhere you choose
./orpheus-installer-1.0.0.sh --uninstall  # remove it again
```

It unpacks the bundle, links the binary onto your `PATH`, and writes a desktop
entry and an icon so Orpheus appears in your applications menu. The per-user
install needs no root and is the default. It keeps a copy of itself beside the
payload, so uninstalling later needs nothing downloaded.

A self-extracting script rather than a `.deb`, a Flatpak or an AppImage, because
each of those assumes something this cannot. A `.deb` assumes `apt`, leaving out
every distribution that does not use it. A Flatpak assumes Flatpak is set up and
adds a sandbox that would have to be punched through for the one thing this
application does — read music folders you chose, anywhere on your disk. An
AppImage is a portable binary rather than an installation: no launcher entry, no
icon.

### Android — APK

Installed directly. Orpheus is not on any store, so your device will ask you to
allow installing from this source.

The package asks for permission to read audio files, to keep playing in the
background, and — for the lyrics lookup alone — to reach the network. Nothing
else. That set is checked by CI against the package that actually ships, and a
permission that is not on the list fails the build.

## Uninstalling

Nothing of yours is removed by an uninstall on any platform. Your library
folders, catalog, listening statistics and settings live in your own application
data directory and are deliberately left in place — an uninstall is not a request
to forget what you listened to, and reinstalling should find it all again.

## Building it yourself

Everything above is produced by [`.github/workflows/release.yml`](https://github.com/artur-rios/orpheus/blob/main/.github/workflows/release.yml)
from a pushed tag. To build the same artifacts locally, see the
[repository README](https://github.com/artur-rios/orpheus#building).
