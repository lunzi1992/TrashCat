#!/usr/bin/env python3
"""
Generate a deterministic DMG background for TrashCat.

Avoid emoji / symbol fonts here. Finder DMG backgrounds are bitmap images, and
emoji fallback is easy to break on different macOS/Pillow combinations.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
OUT = RESOURCES / "dmg-background.png"
APP_ICON = RESOURCES / "icon.png"

W, H = 660, 420
APP_CENTER = (180, 220)
APPS_CENTER = (480, 220)

BG = (250, 250, 248)
ORANGE = (255, 149, 0)
ORANGE_DARK = (210, 112, 0)
TEXT = (42, 42, 42)
MUTED = (118, 118, 118)
LIGHT = (226, 226, 222)
FOLDER_BLUE = (80, 145, 220)
FOLDER_DARK = (42, 99, 176)


def load_font(size: int, bold: bool = False):
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc" if bold else "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def paste_app_icon(img: Image.Image, center: tuple[int, int], size: int = 92):
    if not APP_ICON.exists():
        return

    icon = Image.open(APP_ICON).convert("RGBA")
    resample = getattr(Image, "Resampling", Image).LANCZOS
    icon = icon.resize((size, size), resample)

    x = center[0] - size // 2
    y = center[1] - size // 2
    img.paste(icon, (x, y), icon)


def draw_folder(draw: ImageDraw.ImageDraw, center: tuple[int, int]):
    cx, cy = center
    x0, y0 = cx - 46, cy - 34
    x1, y1 = cx + 46, cy + 38

    draw.rounded_rectangle([x0, y0 + 12, x1, y1], radius=10, fill=FOLDER_BLUE, outline=FOLDER_DARK, width=2)
    draw.rounded_rectangle([x0 + 8, y0, x0 + 44, y0 + 24], radius=6, fill=FOLDER_BLUE, outline=FOLDER_DARK, width=2)
    draw.rectangle([x0 + 34, y0 + 12, x1 - 8, y0 + 24], fill=FOLDER_BLUE)
    draw.line([x0 + 4, y0 + 28, x1 - 4, y0 + 28], fill=(130, 180, 235), width=2)


def main():
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    title = load_font(25, bold=True)
    small = load_font(13)
    mono = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 11)

    draw.text((W // 2, 48), "TrashCat", font=title, anchor="mm", fill=ORANGE_DARK)
    draw.text((W // 2, 80), "拖动 TrashCat 到“应用程序”", font=small, anchor="mm", fill=MUTED)

    arrow_y = 164
    draw.line([(245, arrow_y), (415, arrow_y)], fill=ORANGE, width=3)
    draw.polygon([(415, arrow_y - 8), (435, arrow_y), (415, arrow_y + 8)], fill=ORANGE)

    paste_app_icon(img, APP_CENTER)
    draw_folder(draw, APPS_CENTER)

    draw.line([(42, 330), (W - 42, 330)], fill=LIGHT, width=1)
    draw.text((W // 2, 352), "若 macOS 阻止首次打开，请在终端运行：", font=small, anchor="mm", fill=MUTED)

    draw.rounded_rectangle([120, 370, W - 120, 394], radius=6, fill=(238, 238, 235))
    draw.text((W // 2, 382), "xattr -cr /Applications/TrashCat.app", font=mono, anchor="mm", fill=TEXT)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"DMG background saved: {OUT} ({W}x{H})")


if __name__ == "__main__":
    main()
