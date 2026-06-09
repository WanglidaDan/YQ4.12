#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Resources" / "Assets.xcassets"
APP_ICON_DIR = ASSETS / "AppIcon.appiconset"
BRAND_LOGO = ASSETS / "BrandLogo.imageset" / "BrandLogo.png"

ICON_SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
SCALE = 4
CANVAS = 1024 * SCALE


def rgb(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.strip().removeprefix("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def scaled(value: float) -> int:
    return round(value * SCALE)


def load_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default(size=size)


def draw_rounded_arc(
    draw: ImageDraw.ImageDraw,
    bounds: tuple[int, int, int, int],
    start: float,
    end: float,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    draw.arc(bounds, start=start, end=end, fill=color, width=width)
    cx = (bounds[0] + bounds[2]) / 2
    cy = (bounds[1] + bounds[3]) / 2
    rx = (bounds[2] - bounds[0]) / 2
    ry = (bounds[3] - bounds[1]) / 2
    radius = width / 2
    for angle in (start, end):
        radians = math.radians(angle)
        x = cx + rx * math.cos(radians)
        y = cy + ry * math.sin(radians)
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=color,
        )


def gradient_background() -> Image.Image:
    top_left = rgb("#111820")
    mid = rgb("#283630")
    bottom = rgb("#05070A")
    img = Image.new("RGB", (CANVAS, CANVAS), top_left)
    pixels = img.load()
    for y in range(CANVAS):
        vertical = y / (CANVAS - 1)
        for x in range(CANVAS):
            diagonal = (x + y) / (CANVAS * 2)
            base = mix(top_left, mid, min(1.0, diagonal * 1.55))
            color = mix(base, bottom, max(0.0, vertical - 0.35) * 1.25)
            pixels[x, y] = color
    return img


def draw_brand_mark() -> Image.Image:
    base = gradient_background().convert("RGBA")

    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (scaled(175), scaled(110), scaled(900), scaled(860)),
        fill=(224, 194, 126, 58),
    )
    glow_draw.ellipse(
        (scaled(40), scaled(420), scaled(690), scaled(1110)),
        fill=(68, 118, 106, 42),
    )
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(scaled(90))))

    line_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    line_draw = ImageDraw.Draw(line_layer)
    for offset in range(-CANVAS, CANVAS, scaled(86)):
        line_draw.line(
            [(offset, 0), (offset + CANVAS, CANVAS)],
            fill=(255, 255, 255, 12),
            width=scaled(1),
        )
    base.alpha_composite(line_layer)

    draw = ImageDraw.Draw(base)
    ring_bounds = (scaled(202), scaled(202), scaled(822), scaled(822))
    draw_rounded_arc(draw, ring_bounds, 204, 334, (224, 196, 120, 235), scaled(58))
    draw_rounded_arc(draw, ring_bounds, 20, 150, (112, 165, 146, 220), scaled(58))

    for angle in (30, 58, 86, 114, 142):
        radians = math.radians(angle)
        cx = scaled(512 + 310 * math.cos(radians))
        cy = scaled(512 + 310 * math.sin(radians))
        draw.ellipse(
            (cx - scaled(8), cy - scaled(8), cx + scaled(8), cy + scaled(8)),
            fill=(245, 232, 190, 185),
        )

    draw.ellipse(
        (scaled(308), scaled(308), scaled(716), scaled(716)),
        fill=(8, 14, 18, 212),
        outline=(247, 226, 174, 126),
        width=scaled(8),
    )
    draw.ellipse(
        (scaled(384), scaled(384), scaled(640), scaled(640)),
        fill=(22, 34, 39, 245),
        outline=(255, 255, 255, 46),
        width=scaled(4),
    )

    font = load_font(scaled(208))
    text = "YQ"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (CANVAS - text_w) / 2 - scaled(1)
    y = (CANVAS - text_h) / 2 - scaled(14)
    draw.text((x + scaled(5), y + scaled(8)), text, font=font, fill=(0, 0, 0, 74))
    draw.text((x, y), text, font=font, fill=(250, 246, 235, 250))

    shine = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.polygon(
        [
            (scaled(96), 0),
            (scaled(414), 0),
            (scaled(196), scaled(1024)),
            (0, scaled(1024)),
        ],
        fill=(255, 255, 255, 24),
    )
    base.alpha_composite(shine.filter(ImageFilter.GaussianBlur(scaled(16))))

    return base.convert("RGB")


def save_assets() -> None:
    master = draw_brand_mark()
    APP_ICON_DIR.mkdir(parents=True, exist_ok=True)
    BRAND_LOGO.parent.mkdir(parents=True, exist_ok=True)

    master.resize((1024, 1024), Image.Resampling.LANCZOS).save(BRAND_LOGO, optimize=True)
    for size in ICON_SIZES:
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(APP_ICON_DIR / f"AppIcon-{size}.png", optimize=True)


if __name__ == "__main__":
    save_assets()
