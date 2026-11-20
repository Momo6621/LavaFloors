"""Compose the LAVA Floors thumbnail (1920x1080) and icon (512x512) from in-game Studio screenshots.

Only in-game captures and the game's own free font (Fredoka One, SIL Open Font License) are used.
"""
import sys
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

hero_path, icon_path, font_path, out_dir = sys.argv[1:5]
font_file = font_path


def boost(img, contrast=1.08, colour=1.18, sharp=1.35):
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(colour)
    return ImageEnhance.Sharpness(img).enhance(sharp)


def vignette(img, strength=0.55):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    pad = int(min(w, h) * 0.08)
    d.ellipse((-pad, -pad, w + pad, h + pad), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    dark = Image.new("RGB", (w, h), (40, 8, 0))
    return Image.composite(img, Image.blend(img, dark, strength), mask)


def gradient(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def title(img, text, font_size, centre_x, top_y, stroke, glow):
    """Gradient-filled text with a thick dark outline and an orange glow."""
    font = ImageFont.truetype(font_file, font_size)
    probe = ImageDraw.Draw(img)
    l, t, r, b = probe.textbbox((0, 0), text, font=font, stroke_width=stroke)
    tw, th = r - l, b - t
    x, y = int(centre_x - tw / 2) - l, top_y - t
    # glow
    glow_layer = Image.new("L", img.size, 0)
    ImageDraw.Draw(glow_layer).text((x, y), text, font=font, fill=255, stroke_width=stroke + glow // 3, stroke_fill=255)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(glow))
    img.paste(Image.new("RGB", img.size, (255, 120, 20)), (0, 0), glow_layer.point(lambda v: int(v * 0.85)))
    # outline
    ImageDraw.Draw(img).text((x, y), text, font=font, fill=(70, 12, 0), stroke_width=stroke, stroke_fill=(70, 12, 0))
    # gradient fill
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    # the gradient runs top to bottom across the letters themselves: pale yellow into hot orange
    band = gradient((img.width, th), (255, 250, 150), (255, 110, 10))
    fill = Image.new("RGB", img.size, (255, 110, 10))
    fill.paste(band, (0, top_y))
    fill.paste(Image.new("RGB", (img.width, top_y), (255, 250, 150)), (0, 0))
    img.paste(fill, (0, 0), mask)
    return th


# Thumbnail 1920x1080
hero = Image.open(hero_path).convert("RGB")
scale = max(1920 / hero.width, 1080 / hero.height)
hero = hero.resize((round(hero.width * scale), round(hero.height * scale)), Image.LANCZOS)
top = 40  # keep the King on the pillar comfortably inside the frame
hero = hero.crop((0, top, 1920, top + 1080))
hero = vignette(boost(hero))
title(hero, "LAVA FLOORS", 190, 960, 800, 16, 30)
hero.save(f"{out_dir}/thumbnail-1920x1080.png", optimize=True)

# Icon 512x512: square crop on the crowned climber
icon = Image.open(icon_path).convert("RGB")
icon = icon.crop((270, 70, 860, 660)).resize((512, 512), Image.LANCZOS)
icon = vignette(boost(icon, colour=1.22), 0.45)
title(icon, "LAVA", 92, 256, 330, 9, 14)
title(icon, "FLOORS", 70, 256, 420, 8, 12)
icon.save(f"{out_dir}/icon-512.png", optimize=True)
print("ok")
