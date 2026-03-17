#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
RESOURCES_DIR = ROOT / "Resources"
ICONSET_DIR = RESOURCES_DIR / "AppIcon.iconset"
ICNS_PATH = RESOURCES_DIR / "AppIcon.icns"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def draw_icon(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    inset = int(size * 0.05)
    radius = int(size * 0.24)
    rect = [inset, inset, size - inset, size - inset]

    # Background base.
    draw.rounded_rectangle(rect, radius=radius, fill=(20, 24, 35, 255))

    # Blue atmosphere glow.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        [
            int(size * 0.15),
            int(size * 0.32),
            int(size * 0.92),
            int(size * 0.98),
        ],
        fill=(55, 120, 255, 110),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(4, size // 18)))
    canvas.alpha_composite(glow)

    # Top highlight.
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(
        [inset, inset, size - inset, int(size * 0.45)],
        radius=radius,
        fill=(255, 255, 255, 24),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=max(3, size // 40)))
    canvas.alpha_composite(highlight)

    # Outer border.
    draw.rounded_rectangle(rect, radius=radius, outline=(255, 255, 255, 56), width=max(1, size // 96))

    # Gauge ring.
    ring_box = [
        int(size * 0.21),
        int(size * 0.21),
        int(size * 0.79),
        int(size * 0.79),
    ]
    ring_width = max(3, int(size * 0.085))
    draw.arc(ring_box, start=0, end=360, fill=(80, 89, 112, 190), width=ring_width)

    seg1 = blend((60, 226, 220), (36, 140, 255), 0.55)
    seg2 = (24, 144, 255)
    seg3 = (255, 164, 61)
    draw.arc(ring_box, start=216, end=276, fill=seg1, width=ring_width)
    draw.arc(ring_box, start=278, end=330, fill=seg2, width=ring_width)
    draw.arc(ring_box, start=332, end=344, fill=seg3, width=ring_width)

    # Center chip.
    chip_size = int(size * 0.22)
    chip_x0 = (size - chip_size) // 2
    chip_y0 = (size - chip_size) // 2
    chip_rect = [chip_x0, chip_y0, chip_x0 + chip_size, chip_y0 + chip_size]
    chip_radius = max(1, min(chip_size // 3, max(2, chip_size // 7)))
    draw.rounded_rectangle(chip_rect, radius=chip_radius, fill=(43, 52, 73, 235))
    draw.rounded_rectangle(
        chip_rect,
        radius=chip_radius,
        outline=(255, 255, 255, 42),
        width=max(1, size // 128),
    )

    # Chip pins.
    pin_len = max(2, chip_size // 10)
    pin_w = max(1, size // 80)
    pin_color = (151, 164, 196, 170)
    for i in range(4):
        offset = int((i + 1) * chip_size / 5)
        x = chip_x0 + offset
        draw.line((x, chip_y0 - pin_len, x, chip_y0), fill=pin_color, width=pin_w)
        draw.line((x, chip_y0 + chip_size, x, chip_y0 + chip_size + pin_len), fill=pin_color, width=pin_w)
        y = chip_y0 + offset
        draw.line((chip_x0 - pin_len, y, chip_x0, y), fill=pin_color, width=pin_w)
        draw.line((chip_x0 + chip_size, y, chip_x0 + chip_size + pin_len, y), fill=pin_color, width=pin_w)

    inner_margin = max(1, min(max(1, chip_size // 5), max(1, (chip_size - 2) // 2)))
    inner_rect = [
        chip_x0 + inner_margin,
        chip_y0 + inner_margin,
        chip_x0 + chip_size - inner_margin,
        chip_y0 + chip_size - inner_margin,
    ]
    draw.rounded_rectangle(
        inner_rect,
        radius=max(1, min((inner_rect[2] - inner_rect[0]) // 3, max(1, chip_radius // 2))),
        fill=(16, 21, 31, 180),
        outline=(96, 174, 255, 120),
        width=max(1, size // 160),
    )

    return canvas


def save_iconset() -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    sizes = [16, 32, 128, 256, 512]
    for size in sizes:
        draw_icon(size).save(ICONSET_DIR / f"icon_{size}x{size}.png")
        draw_icon(size * 2).save(ICONSET_DIR / f"icon_{size}x{size}@2x.png")


def build_icns() -> None:
    RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    save_iconset()
    if ICNS_PATH.exists():
        ICNS_PATH.unlink()
    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_PATH)],
        check=True,
    )


if __name__ == "__main__":
    build_icns()
    print(ICNS_PATH)
