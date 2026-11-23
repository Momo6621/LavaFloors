"""Compose the bold LAVA Floors thumbnail (1920x1080) and icon (512x512).

Inputs are in-game material only: an in-game screenshot for the background and Studio captures of the game's own
R15 rigs, crown and fruit buddies posed against a flat neon-green backdrop (chroma-keyed here). The title uses
Luckiest Guy, the game's UI font (Apache 2.0, shipped with Roblox Studio).

Usage: python tools/compose_pop_art.py <background.jpg> <font.ttf> <out_dir> winner=<jpg> shoved=<jpg>
       leaper=<jpg> buddy1=<jpg> buddy2=<jpg>
"""
import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

bg_path, font_path, out_dir = sys.argv[1:4]
shots = dict(a.split("=", 1) for a in sys.argv[4:])
random.seed(7)


def cutout(path, crop=(250, 60, 900, 700)):
    """Chroma-key a neon-green capture; returns an RGBA image trimmed to the subject."""
    img = Image.open(path).convert("RGB").crop(crop)
    w, h = img.size
    px = img.load()
    alpha = Image.new("L", (w, h), 0)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = g - max(r, b)  # how green this pixel is
            a = 1.0 - min(1.0, max(0.0, (d - 40) / 140))
            ap[x, y] = int(a * 255)
            if d > 0:  # de-spill the green fringe
                px[x, y] = (r, max(r, b), b)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = img.convert("RGBA")
    out.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    return out.crop(box)


def boost(img, colour=1.25, contrast=1.1):
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(colour)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def sticker(img, outline=10, shadow=14):
    """White sticker outline and a soft dark drop shadow, like kids' game thumbnails."""
    pad = outline + shadow * 2
    w, h = img.size
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = Image.new("L", canvas.size, 0)
    a.paste(img.getchannel("A"), (pad, pad))
    ring = a.filter(ImageFilter.MaxFilter(outline * 2 + 1))
    shade = ring.filter(ImageFilter.GaussianBlur(shadow)).point(lambda v: int(v * 0.6))
    canvas.paste((40, 10, 0, 255), (shadow // 2, shadow), shade)
    canvas.paste((255, 255, 255, 255), (0, 0), ring)
    canvas.alpha_composite(img, (pad, pad))
    return canvas


def fit(img, height):
    s = height / img.height
    return img.resize((max(1, round(img.width * s)), round(height)), Image.LANCZOS)


def place(base, img, cx, cy, angle=0):
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    base.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))


def burst(size, centre, rays=18, colour=(255, 240, 160), alpha=70):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = centre
    r = max(size) * 1.5
    for i in range(rays):
        a0 = 2 * math.pi * i / rays
        a1 = a0 + math.pi / rays
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))],
                  fill=colour + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(3))


def sparkles(base, n, area, size_range):
    d = ImageDraw.Draw(base)
    x0, y0, x1, y1 = area
    for _ in range(n):
        x, y = random.uniform(x0, x1), random.uniform(y0, y1)
        s = random.uniform(*size_range)
        col = random.choice([(255, 255, 255, 255), (255, 240, 140, 255), (255, 200, 80, 255)])
        d.polygon([(x, y - s), (x + s * 0.22, y - s * 0.22), (x + s, y), (x + s * 0.22, y + s * 0.22), (x, y + s),
                   (x - s * 0.22, y + s * 0.22), (x - s, y), (x - s * 0.22, y - s * 0.22)], fill=col)


def title(base, text, size, cx, top, angle=-3, stroke=16, white=9):
    """Chunky title: white outer outline, dark brown inner outline, yellow-to-orange fill, glow and shadow."""
    font = ImageFont.truetype(font_path, size)
    probe = ImageDraw.Draw(base)
    l, t, r, b = probe.textbbox((0, 0), text, font=font, stroke_width=stroke + white)
    w, h = r - l + 40, b - t + 40
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x, y = 20 - l, 20 - t
    d = ImageDraw.Draw(layer)
    d.text((x, y), text, font=font, fill=(255, 255, 255, 255), stroke_width=stroke + white, stroke_fill=(255, 255, 255, 255))
    d.text((x, y), text, font=font, fill=(90, 22, 0, 255), stroke_width=stroke, stroke_fill=(90, 22, 0, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    for yy in range(h):
        t_ = min(1, max(0, (yy - y) / max(1, (b - t))))
        gd.line([(0, yy), (w, yy)], fill=(255, int(250 - 130 * t_), int(130 - 120 * t_), 255))
    layer.paste(grad, (0, 0), mask)
    # shine across the top of the letters
    shine = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shine).rectangle((0, 0, w, y + (b - t) * 0.38), fill=70)
    layer.paste((255, 255, 255, 255), (0, 0), ImageChops.multiply(mask, shine))
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    glow = Image.new("RGBA", layer.size, (255, 140, 20, 0))
    glow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(22)).point(lambda v: int(v * 0.9)))
    shadow = Image.new("RGBA", layer.size, (30, 5, 0, 0))
    shadow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(8)).point(lambda v: int(v * 0.7)))
    px, py = int(cx - layer.width / 2), int(top)
    base.alpha_composite(glow, (px, py))
    base.alpha_composite(shadow, (px + 6, py + 12))
    base.alpha_composite(layer, (px, py))


def background(size):
    bg = Image.open(bg_path).convert("RGB")
    s = max(size[0] / bg.width, size[1] / bg.height)
    bg = bg.resize((round(bg.width * s), round(bg.height * s)), Image.LANCZOS)
    x = (bg.width - size[0]) // 2
    y = (bg.height - size[1]) // 2
    bg = bg.crop((x, y, x + size[0], y + size[1]))
    bg = ImageEnhance.Color(bg).enhance(1.45)
    bg = ImageEnhance.Contrast(bg).enhance(1.15)
    bg = ImageEnhance.Brightness(bg).enhance(1.08)
    bg = bg.filter(ImageFilter.GaussianBlur(2.5))
    out = bg.convert("RGBA")
    # hot lava glow rising from the bottom
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for yy in range(size[1]):
        t = max(0, (yy - size[1] * 0.55) / (size[1] * 0.45))
        gd.line([(0, yy), (size[0], yy)], fill=(255, 110, 0, int(140 * t * t)))
    out.alpha_composite(glow)
    return out


winner = sticker(boost(cutout(shots["winner"])))
shoved = sticker(boost(cutout(shots["shoved"])))
leaper = sticker(boost(cutout(shots["leaper"])))
buddy1 = sticker(boost(cutout(shots["buddy1"], (380, 180, 760, 560))), outline=8)
buddy2 = sticker(boost(cutout(shots["buddy2"], (380, 180, 760, 560))), outline=8)

# Thumbnail 1920x1080
W, H = 1920, 1080
thumb = background((W, H))
thumb.alpha_composite(burst((W, H), (W / 2, 300)))
place(thumb, fit(shoved, 470), 400, 640, angle=8)
place(thumb, fit(leaper, 500), 1530, 660, angle=-6)
place(thumb, fit(winner, 640), 960, 700)
place(thumb, fit(buddy1, 250), 190, 930, angle=-10)
place(thumb, fit(buddy2, 240), 1740, 940, angle=10)
sparkles(thumb, 26, (60, 260, W - 60, H - 40), (10, 26))
title(thumb, "LAVA FLOORS", 230, W / 2, 20)
thumb.convert("RGB").save(f"{out_dir}/thumbnail-1920x1080.png", optimize=True)

# Icon 512x512: the crowned winner, a buddy and the title
S = 512
icon = background((S, S))
icon.alpha_composite(burst((S, S), (S / 2, S * 0.42), rays=14, alpha=90))
place(icon, fit(winner, 330), S * 0.55, S * 0.43)
place(icon, fit(buddy1, 120), S * 0.17, S * 0.52, angle=-12)
sparkles(icon, 8, (20, 20, S - 20, S * 0.7), (6, 13))
title(icon, "LAVA", 118, S / 2, S * 0.60, angle=-4, stroke=9, white=6)
icon.convert("RGB").save(f"{out_dir}/icon-512.png", optimize=True)
print("ok")
