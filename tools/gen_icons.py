#!/usr/bin/env python3
"""Generator ikon launcher Hadir (PIL) — dapat dijalankan ulang kapan saja.

Menghasilkan:
  - mipmap-*/ic_launcher.png           (legacy, kotak membulat + huruf H)
  - mipmap-*/ic_launcher_foreground.png (adaptive, H putih transparan)
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"

BG = (26, 35, 126, 255)      # indigo 900
FG = (255, 255, 255, 255)

LEGACY = {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
          "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}
FOREGROUND = {"mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
              "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432}


def draw_h(draw, size, margin, bar, vspan):
    """Gambar huruf H dari tiga persegi (dua kaki + palang)."""
    ya, yb = size * vspan[0], size * vspan[1]
    cy = size / 2 - bar / 2
    draw.rectangle([margin, ya, margin + bar, yb], fill=FG)
    draw.rectangle([size - margin - bar, ya, size - margin, yb], fill=FG)
    draw.rectangle([margin, cy, size - margin, cy + bar], fill=FG)


def legacy_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = max(4, round(size * 0.18))
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=BG)
    draw_h(draw, size, margin=size * 0.22, bar=size * 0.20,
           vspan=(0.30, 0.70))
    return img


def foreground_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Zona aman adaptive icon: konten inti <= 66% bidang.
    draw_h(draw, size, margin=size * 0.27, bar=size * 0.17,
           vspan=(0.31, 0.69))
    return img


def main():
    for folder, size in LEGACY.items():
        path = ROOT / folder / "ic_launcher.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        legacy_icon(size).save(path)
        print(f"  {path.relative_to(ROOT.parent.parent.parent.parent.parent)} ({size}x{size})")
    for folder, size in FOREGROUND.items():
        path = ROOT / folder / "ic_launcher_foreground.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        foreground_icon(size).save(path)
        print(f"  {path.relative_to(ROOT.parent.parent.parent.parent.parent)} ({size}x{size})")


if __name__ == "__main__":
    main()
