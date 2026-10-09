#!/usr/bin/env python3
"""Generate the seven-segment and dot-matrix bitmap fonts and the launcher icon.

Usage: python3 tools/gen_assets.py --screen 454
Requires Pillow. Nothing is derived from third-party fonts: every glyph is drawn here.
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4  # supersampling factor
SLANT = math.tan(math.radians(8))
DIGITS = "0123456789"

# Digit heights as fractions of the screen radius
BIG = 0.40
SMALL = 0.17

# Which of the segments a-g are lit
SEGMENTS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
            "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abfgcd", "-": "g"}

# 5x7 dot matrix for the weekday letters, the unit letters and the degree sign
LETTERS = {
    "°": ["01100", "10010", "10010", "01100", "00000", "00000", "00000"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
}


def slant(points, h):
    return [(x + (h - y) * SLANT, y) for x, y in points]


def segment_glyph(ch, w, h, t):
    """One seven-segment character on a supersampled cell, slanted like an LCD module."""
    gap = t * 0.18
    left, right, top, mid, bottom = t / 2, w - t / 2, t / 2, h / 2, h - t / 2

    def bar(x0, y0, x1, y1):
        if y0 == y1:  # horizontal, pointed ends
            x0, x1 = x0 + gap, x1 - gap
            return [(x0, y0), (x0 + t / 2, y0 - t / 2), (x1 - t / 2, y0 - t / 2),
                    (x1, y0), (x1 - t / 2, y0 + t / 2), (x0 + t / 2, y0 + t / 2)]
        y0, y1 = y0 + gap, y1 - gap
        return [(x0, y0), (x0 + t / 2, y0 + t / 2), (x0 + t / 2, y1 - t / 2),
                (x0, y1), (x0 - t / 2, y1 - t / 2), (x0 - t / 2, y0 + t / 2)]

    bars = {"a": bar(left, top, right, top), "g": bar(left, mid, right, mid), "d": bar(left, bottom, right, bottom),
            "f": bar(left, top, left, mid), "b": bar(right, top, right, mid),
            "e": bar(left, mid, left, bottom), "c": bar(right, mid, right, bottom)}
    img = Image.new("L", (round(w + h * SLANT), h), 0)
    draw = ImageDraw.Draw(img)
    if ch == ":":
        for y in (h * 0.32, h * 0.68):
            draw.polygon(slant([(w / 2 - t / 2, y - t / 2), (w / 2 + t / 2, y - t / 2),
                                (w / 2 + t / 2, y + t / 2), (w / 2 - t / 2, y + t / 2)], h), fill=255)
    else:
        for name in SEGMENTS[ch]:
            draw.polygon(slant(bars[name], h), fill=255)
    return img


def letter_glyph(ch, w, h):
    rows = LETTERS[ch]
    cell_w, cell_h = w / 5, h / 7
    img = Image.new("L", (round(w + h * SLANT), h), 0)
    draw = ImageDraw.Draw(img)
    for r, row in enumerate(rows):
        for c, bit in enumerate(row):
            if bit == "1":
                x0, y0 = c * cell_w, r * cell_h
                x1, y1 = x0 + cell_w * 0.86, y0 + cell_h * 0.86
                draw.polygon(slant([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], h), fill=255)
    return img


def write_font(name, chars, glyphs, bearing, out_dir):
    """Pack supersampled glyphs into a BMFont atlas; the advance leaves `bearing` after the slanted cell."""
    cells = [g.resize((max(1, g.width // SS), g.height // SS), Image.LANCZOS) for g in glyphs]
    height = cells[0].height
    atlas = Image.new("L", (sum(c.width + 1 for c in cells), height), 0)
    lines = [
        f'info face="{name}" size={height} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={height} base={height} scaleW={atlas.width} scaleH={height} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(cells)}",
    ]
    x = 0
    for ch, cell in zip(chars, cells):
        atlas.paste(cell, (x, 0))
        lines.append(
            f"char id={ord(ch)} x={x} y=0 width={cell.width} height={height} "
            f"xoffset=0 yoffset=0 xadvance={cell.width + bearing} page=0 chnl=15"
        )
        x += cell.width + 1
    atlas.save(out_dir / f"{name}.png")
    (out_dir / f"{name}.fnt").write_text("\n".join(lines) + "\n")


def segment_font(name, radius, fraction, out_dir, letters=False):
    h = round(radius * fraction) * SS
    w, t = round(h * 0.52), round(h * 0.10)
    chars = DIGITS + ("-" if letters else ":")
    glyphs = [segment_glyph(ch, w if ch != ":" else round(w * 0.45), h, t) for ch in chars]
    if letters:
        chars += "".join(sorted(LETTERS))
        glyphs += [letter_glyph(ch, w, h) for ch in sorted(LETTERS)]
    write_font(name, chars, glyphs, round(w * 0.12 / SS), out_dir)


def write_icon(path, size):
    h = size * SS * 6 // 10
    w, t = round(h * 0.52), round(h * 0.12)
    img = Image.new("L", (size * SS, size * SS), 0)
    glyph = segment_glyph("8", w, h, t)
    img.paste(glyph, ((img.width - glyph.width) // 2, (img.height - h) // 2))
    img.resize((size, size), Image.LANCZOS).convert("RGB").save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--screen", type=int, required=True, help="screen width in pixels")
    parser.add_argument("--icon", type=int, default=65, help="launcher icon size in pixels")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent / "resources"
    radius = args.screen / 2
    segment_font("seg_big", radius, BIG, root / "fonts")
    segment_font("seg_small", radius, SMALL, root / "fonts", letters=True)
    write_icon(root / "drawables" / "launcher_icon.png", args.icon)


if __name__ == "__main__":
    main()
