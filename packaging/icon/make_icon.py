#!/usr/bin/env python3
"""Draws the Orpheus application icon and writes every size each platform wants.

The icon is a lyre — Orpheus's own instrument — whose strings are the sound
bars from the player screen, standing at the uneven heights a level meter
stands at. It is the name and the application's own motif in one mark.

Drawn in code rather than kept as a binary nobody can edit: a change to the
palette, the proportions or the string heights is a diff here, and every size
is regenerated from the same source by running this file.

    python3 packaging/icon/make_icon.py

Needs Pillow, and nothing else. Writes into android/, windows/ and linux/.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

# ------------------------------------------------------------------ the palette

# The seed the application's own themes are generated from, and two shades of
# it: a flat ground reads as a sticker, and this reads as a surface.
GROUND_TOP = (74, 111, 165)
GROUND_BOTTOM = (52, 79, 121)

# The frame of the instrument. Not pure white: against the blue it would glare,
# and every real icon at this size is a little warmer than the paper it sits on.
FRAME = (239, 244, 251)

# The strings, which are the bars. Gold because Orpheus's lyre was, and because
# it is the one hue that separates the strings from the frame at every size.
STRING = (245, 201, 122)

# What the whole mark is drawn in before it is scaled down. Everything below is
# in these units, so the proportions are readable as numbers.
UNITS = 1024


def rounded_ground(draw: ImageDraw.ImageDraw, size: int, radius: int) -> None:
    """The rounded square everything else sits on, with a vertical gradient."""
    for y in range(size):
        into = y / max(1, size - 1)
        draw.line(
            [(0, y), (size, y)],
            fill=tuple(
                round(top + (bottom - top) * into)
                for top, bottom in zip(GROUND_TOP, GROUND_BOTTOM)
            ),
        )


def bezier(start, first, second, end, steps: int = 400):
    """The points along a cubic curve, which is what an arm of a lyre is.

    Cubic rather than quadratic because of the shape being drawn: an arm bows
    outward from the soundbox and then comes back *in* toward its tip, and a
    curve with one control point can only bow one way — which is a bowl.
    """
    points = []
    for step in range(steps + 1):
        t = step / steps
        u = 1 - t
        points.append(
            tuple(
                u * u * u * start[axis]
                + 3 * u * u * t * first[axis]
                + 3 * u * t * t * second[axis]
                + t * t * t * end[axis]
                for axis in (0, 1)
            )
        )
    return points


def capsule(draw: ImageDraw.ImageDraw, x0, y0, x1, y1, fill) -> None:
    """A bar with round ends — the shape the player draws its bars with.

    The radius comes from the shorter side, so the same call draws an upright
    string and a level yoke. Taking it from the width instead rounds a long
    horizontal bar into an oval, which is what turns a lyre into a bowl.
    """
    draw.rounded_rectangle(
        [x0, y0, x1, y1], radius=min(x1 - x0, y1 - y0) / 2, fill=fill
    )


def stroke(draw: ImageDraw.ImageDraw, points, width: float, fill) -> None:
    """A thick curve, stamped as overlapping discs.

    Stamped rather than drawn as a polyline: a wide line through a curve leaves
    hairline notches on the outside of every bend, and at this width they are
    visible in the finished icon. A disc per sampled point has no joins to
    notch, and gives round ends for nothing.
    """
    for x, y in points:
        draw.ellipse(
            [x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=fill
        )


def draw_full(size: int, ground: bool = True) -> Image.Image:
    """The whole mark: the frame of a lyre with the bars strung inside it.

    Without [ground] the instrument is drawn alone on transparency, which is
    what Android's adaptive icon wants: there the system composes the mark over
    a background of its own and masks the pair to whatever shape the launcher
    uses, so a mark carrying its own square would show that square's edge.
    """
    scale = size / UNITS
    canvas = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(canvas)

    def at(value: float) -> float:
        return value * scale

    if ground:
        rounded_ground(draw, size, round(at(184)))

    # The two arms. Out from the soundbox, wide at the waist, and back in to a
    # tip — the tips closer together than the widest point is the whole of what
    # makes a lyre read as one rather than as a bowl.
    for start, first, second, end in (
        ((354, 714), (222, 640), (224, 332), (334, 226)),
        ((670, 714), (802, 640), (800, 332), (690, 226)),
    ):
        stroke(
            draw,
            [(at(x), at(y)) for x, y in bezier(start, first, second, end)],
            at(44),
            FRAME,
        )

    # The yoke, across the arms and short of their tips, which stand above it
    # as the horns of the instrument.
    capsule(draw, at(300), at(258), at(724), at(304), FRAME)

    # The strings, at the heights a level meter stands at rather than all the
    # same: it is what makes the instrument read as one that is being played.
    tops = (456, 362, 326, 392, 502)
    left, width, pitch = 340.0, 44.0, 72.0
    for index, top in enumerate(tops):
        x = left + index * pitch
        capsule(draw, at(x), at(top), at(x + width), at(716), STRING)

    # The soundbox last, across the feet of the strings, which is where a
    # lyre's strings actually end.
    capsule(draw, at(330), at(702), at(694), at(802), FRAME)

    return canvas


def draw_small(size: int, ground: bool = True) -> Image.Image:
    """The mark for sixteen and thirty-two pixels.

    The arms and the yoke are a stroke under two pixels wide at those sizes,
    which is not a lyre, it is grey fringing. What survives is what the mark is
    about: three bars at three heights on their soundbox — so that is what is
    drawn, rather than the whole thing blurred.
    """
    scale = size / UNITS
    canvas = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(canvas)

    def at(value: float) -> float:
        return value * scale

    if ground:
        rounded_ground(draw, size, round(at(184)))

    for index, top in enumerate((430, 250, 360)):
        x = 268.0 + index * 176.0
        capsule(draw, at(x), at(top), at(x + 128), at(700), STRING)

    capsule(draw, at(232), at(700), at(792), at(818), FRAME)

    return canvas


def rounded(image: Image.Image, radius_units: float = 184) -> Image.Image:
    """Cuts [image] to a rounded square, which is what every platform expects."""
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.size[0] - 1, image.size[1] - 1],
        radius=round(radius_units * image.size[0] / UNITS),
        fill=255,
    )
    cut = image.copy()
    cut.putalpha(mask)

    return cut


def render(
    size: int,
    detail: str = "full",
    square: bool = False,
    ground: bool = True,
) -> Image.Image:
    """One icon at [size], drawn large and scaled down so the edges are clean."""
    drawn = 2048 if size <= 512 else size * 4
    image = (draw_full if detail == "full" else draw_small)(drawn, ground)
    image = image.resize((size, size), Image.LANCZOS)

    return image if square or not ground else rounded(image)


def write(path: str, image: Image.Image) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print(f"  {path}  {image.size[0]}x{image.size[1]}")


def main() -> None:
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.normpath(root)

    print("the master")
    write(os.path.join(root, "packaging/icon/orpheus.png"), render(1024))

    print("android")
    # Two icons per density, because Android has two launcher icons. The
    # square one is what releases before Android 8 show; the foreground is the
    # layer the adaptive icon composes over a flat background and masks to the
    # launcher's shape, and it is 108dp where the other is 48dp because the
    # outer ring of it is what the mask crops away.
    for density, legacy, adaptive in (
        ("mdpi", 48, 108),
        ("hdpi", 72, 162),
        ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324),
        ("xxxhdpi", 192, 432),
    ):
        folder = os.path.join(root, f"android/app/src/main/res/mipmap-{density}")
        write(os.path.join(folder, "ic_launcher.png"), render(legacy))
        write(
            os.path.join(folder, "ic_launcher_foreground.png"),
            render(adaptive, ground=False),
        )

    print("windows")
    # Every size is drawn rather than resized from the largest: an .ico saved
    # from one image is that image downsampled six times, and the two smallest
    # of those are the mush this file has a second drawing to avoid. Pillow
    # takes the extra frames through `append_images`, each at its own size.
    frames = [
        render(256),
        render(128),
        render(64),
        render(48),
        render(32, detail="small"),
        render(16, detail="small"),
    ]
    icon = os.path.join(root, "windows/runner/resources/app_icon.ico")
    os.makedirs(os.path.dirname(icon), exist_ok=True)
    frames[0].save(
        icon,
        format="ICO",
        sizes=[frame.size for frame in frames],
        append_images=frames[1:],
    )
    print(f"  {icon}  {', '.join(str(f.size[0]) for f in frames)}")

    print("android background")
    # The adaptive icon's background is one flat colour rather than the
    # gradient the square icon has: it is drawn under a mask the launcher
    # chooses and may be animated behind the foreground, and a gradient
    # surviving that is not something to rely on.
    background = os.path.join(
        root, "android/app/src/main/res/values/ic_launcher_background.xml"
    )
    os.makedirs(os.path.dirname(background), exist_ok=True)
    with open(background, "w", encoding="utf-8") as file:
        file.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
            "</resources>\n" % GROUND_TOP
        )
    print(f"  {background}")

    print("linux")
    write(os.path.join(root, "linux/runner/resources/app_icon.png"), render(256))


if __name__ == "__main__":
    main()
