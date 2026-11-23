"""Build the 512x512 icons for the game passes, developer products and badges.

Made from scratch with Pillow: the game's lava colours, Fredoka One (the free font Roblox ships, SIL Open Font
License) for the labels, and Windows' Segoe UI Emoji for the pictures. No generated imagery.
Badge icons keep everything inside the centre circle, since Roblox shows badges as circles.

Usage: python tools/compose_shop_icons.py   (writes Media/store/*.png)
"""

import glob
import os
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 512
OUT = pathlib.Path(__file__).resolve().parent.parent / "Media" / "store"
EMOJI_FONT = "C:/Windows/Fonts/seguiemj.ttf"


def fredoka() -> str:
    found = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf"))
    if not found:
        raise SystemExit("Fredoka One not found: install Roblox Studio or point fredoka() at the font")
    return found[0]


def lava_background(inner=(255, 196, 92), outer=(176, 34, 12)) -> Image.Image:
    """Radial glow: warm gold in the middle fading to deep lava red at the edges."""
    img = Image.new("RGB", (SIZE, SIZE), outer)
    px = img.load()
    c = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            t = min(1.0, (((x - c) ** 2 + (y - c * 0.85) ** 2) ** 0.5) / (SIZE * 0.62))
            t = t * t
            px[x, y] = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def emoji(img: Image.Image, char: str, size: int, centre_y: int):
    font = ImageFont.truetype(EMOJI_FONT, size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = d.textbbox((0, 0), char, font=font, embedded_color=True)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((SIZE - w) / 2 - box[0], centre_y - h / 2 - box[1]), char, font=font, embedded_color=True)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((40, 8, 0, 150), mask=layer.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(shadow, (0, 10))
    img.alpha_composite(layer)


def label(img: Image.Image, text: str, centre_y: int, max_width: int, start: int = 96):
    path = fredoka()
    size = start
    while True:
        font = ImageFont.truetype(path, size)
        d = ImageDraw.Draw(img)
        box = d.textbbox((0, 0), text, font=font, stroke_width=max(4, size // 12))
        if box[2] - box[0] <= max_width or size <= 28:
            break
        size -= 4
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((SIZE - w) / 2 - box[0], centre_y - h / 2 - box[1]), text, font=font, fill=(255, 255, 255),
           stroke_width=max(4, size // 12), stroke_fill=(70, 14, 0))


def icon(name: str, char: str, text: str, badge: bool = False, inner=(255, 196, 92), outer=(176, 34, 12)):
    img = lava_background(inner, outer).convert("RGBA")
    if badge:
        # Everything inside the circle Roblox crops badges to, with a gold rim.
        ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse((14, 14, SIZE - 14, SIZE - 14), outline=(255, 214, 90, 255), width=18)
        img.alpha_composite(ring)
        emoji(img, char, 190, 215)
        label(img, text, 360, 330, 76)
    else:
        emoji(img, char, 230, 205)
        label(img, text, 410, 440)
    OUT.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT / f"{name}.png")


def main():
    gold, deep = (255, 214, 110), (150, 60, 0)
    # Game passes
    icon("pass-vip", "\u2b50", "VIP", inner=gold, outer=deep)
    icon("pass-lavapass", "\U0001F39F", "PASS+", inner=(214, 160, 255), outer=(90, 30, 150))
    icon("pass-2xcoins", "\U0001F4B0", "2x COINS")
    icon("pass-aurora", "\U0001F9E4", "AURORA", inner=(150, 240, 255), outer=(20, 90, 170))
    icon("pass-trail", "\U0001F525", "TRAIL")
    # Developer products: coin packs and tips
    for amount, text in ((100, "100"), (500, "500"), (2000, "2,000"), (6000, "6,000")):
        icon(f"coins-{amount}", "\U0001F4B0", text)
    for amount in (25, 100, 500, 1000):
        icon(f"tip-{amount}", "\U0001F496", f"TIP {amount:,}", inner=(255, 190, 220), outer=(170, 30, 90))
    # Badges
    icon("badge-first-round", "\U0001F30B", "FIRST CLIMB", badge=True)
    icon("badge-first-crown", "\U0001F451", "FIRST CROWN", badge=True, inner=gold, outer=deep)
    icon("badge-ten-crowns", "\U0001F3C6", "10 CROWNS", badge=True, inner=gold, outer=deep)
    icon("badge-friend", "\U0001F465", "WITH A FRIEND", badge=True, inner=(170, 240, 200), outer=(20, 120, 80))
    print("wrote", len(list(OUT.glob("*.png"))), "icons to", OUT)


if __name__ == "__main__":
    main()
