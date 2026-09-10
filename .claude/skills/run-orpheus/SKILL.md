---
name: run-orpheus
description: Use when launching, driving or screenshotting the Orpheus desktop app on Linux to see a change working in the real application — not the test suite. Covers the headless display, the fake sound card, building a playable tagged library to point it at, seeding the preferences so it starts on that library, and driving the window. Triggers on "run the app", "launch Orpheus", "screenshot the player", "does this work in the real app", "verify it end to end".
---

# Running Orpheus on a headless Linux box

`flutter test` never opens a window, a socket or an audio device. This is how
to get the real application running so you can watch it do something, and the
four things about a container that stop it before you see a single frame.

Everything here was established by doing it. Where a step exists to work
around something, the symptom it fixes is written down, because the symptom is
what you will actually meet.

## Do not use `pkill`

`pkill -f <anything matching the harness>` kills the shell running the command
and returns **exit 144** with no output. It looks like the box broke. Kill by
explicit pid instead:

```sh
kill "$(pgrep -f 'bundle/orpheus' | head -1)"
```

## 1. A display it can actually draw on

```sh
Xvfb :98 -screen 0 1400x950x24 -ac   # run in the background
```

**24-bit depth is not optional.** A 16bpp screen renders fine but screenshots
fail with `OSError: unsupported bit depth: 16`. Check for an Xvfb another
session already left behind before starting one — `pgrep -a Xvfb` — and take a
free display number rather than killing theirs.

Screenshots, with no `scrot`/`import`/`ffmpeg` in the box:

```python
from PIL import ImageGrab
ImageGrab.grab(xdisplay=':98').save('shot.png')
```

Then **look at the image**. A blank frame is a failed launch.

## 2. A sound card that does not exist

There is no `/dev/snd` card. libmpv fails with `cannot find card '0'` and
`couldn't open play stream`, and the consequence is subtler than silence: the
player never gets a current track, so **the now-playing screen says "Nothing is
playing" and anything keyed to the current track — the lyrics panel, the sound
bars — never mounts at all.** If you are verifying one of those, you will
conclude it is broken when it was never asked.

```sh
printf 'pcm.!default { type null }\nctl.!default { type null }\n' > ~/.asoundrc
```

Delete it when you are done. **Caveat:** a null sink consumes samples as fast
as they decode, so playback runs several times faster than wall clock and a
four-minute track ends in about a minute. Fine for "does it start", useless for
anything timed — see *Known dead end* below.

## 3. A library worth pointing at

The catalog is built from tags, so the files need real ones, and the player
needs audio that actually decodes. There is no encoder in the box:

```sh
apt-get install -y -q flac
```

Generate near-silent audio of a realistic length — FLAC compresses it to a few
hundred KB, and the duration tag comes out right because it is read from
STREAMINFO:

```sh
python3 - <<'PY'
import wave, struct
n = 284 * 8000
with wave.open('/tmp/a.wav', 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
    w.writeframes(b''.join(struct.pack('<h', (i % 3) - 1) for i in range(n)))
PY
flac -s -f --best -o "$MUSIC/Radiohead/OK Computer/01 - Airbag.flac" \
  -T ARTIST=Radiohead -T TITLE=Airbag -T ALBUM="OK Computer" -T TRACKNUMBER=1 /tmp/a.wav
```

Confirm it decodes before trusting it: `mpv --no-video --ao=null --length=2 <file>`
must end with `Exiting... (End of file)`. `Errors when loading file` means the
header parses but the stream is a stub — the scanner will list it and the
player will not play it.

Use real artist and title tags if you are exercising anything that looks a
track up by them.

## 4. Preferences, so it starts on that library

Adding a folder through the interface means driving a GTK folder picker. Write
the file the application reads instead. Linux support directory:

    ~/.local/share/io.github.artur_rios.orpheus/

`shared_preferences.json` there, every key prefixed `flutter.`:

```python
import json
json.dump({
  "flutter.libraryFolders": ["/path/to/music"],
  "flutter.rescansAtStartup": True,
  "flutter.opensPlayerOnPlay": True,   # play opens the full player for you
  "flutter.volume": 0.0,
}, open(prefs, 'w'))
```

### Getting the phone arrangement

Below 600 logical pixels the shell moves its destinations to the bottom and the
playback bar drops what a phone has no room for, and **that arrangement is
where the mobile bugs are**. There is no window manager to drag a corner with,
so seed the geometry the window restores itself to — same file, one more key,
and the value is a JSON string rather than an object:

```python
data['flutter.windowBounds'] = json.dumps(
    {'x': 30, 'y': 40, 'width': 430, 'height': 860})
```

Anything under `Breakpoint.minimumWindowSize` (420x560) is discarded rather
than clamped, so a width of 430 is about as narrow as it will go. Start Xvfb
big enough to hold the window at its offset and crop the screenshot.

Delete `catalog.json`, `play-history.json`, `covers/`, `energy/` and
`scratch/` from that directory for a genuinely first-run state — and delete
what you seeded afterwards, or the developer's own app starts pointing at a
temporary folder.

## 5. Launch and drive

```sh
DISPLAY=:98 ./build/linux/x64/release/bundle/orpheus   # in the background
```

`libEGL warning: DRI3 error` and the Impeller line are normal. The window is
`Orpheus`; it is 1280x820 inset at (60,65) on a 1400x950 screen, so screenshot
coordinates are absolute and already include that offset.

```sh
DISPLAY=:98 xdotool mousemove <x> <y> click 1
```

Clicks land while the window is freshly mapped. There is **no window manager**,
so `xdotool windowactivate` fails with *"your windowmanager claims not to
support _NET_ACTIVE_WINDOW"* and clicks get unreliable once focus drifts.
Screenshot after every click and confirm you got the state you expected before
sending the next one.

To assert on something animating without reading pixels by eye, mask for the
theme's primary colour and track where it is:

```python
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mask = (b - np.maximum(r, g) > 40) & (b > 90)
```

Zero changed pixels between two frames means playback stopped, not that the
feature is broken.

## Known dead end

**Anything that has to follow playback over time cannot be driven here yet.**
The null sink races the track to its end within a minute, and once it stops,
the absent window manager makes it hard to click play again. Verifying a
timed behaviour needs a real sink (a PipeWire or PulseAudio dummy sink that
runs at wall clock) and a lightweight window manager for reliable focus. If
you fix that, replace this section with what worked.
