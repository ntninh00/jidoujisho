"""Draws the app icon and writes every launcher icon and splash image.

The icon is a brush-written 辞 signed with a small red seal, as a calligrapher
signs a piece. The seal reads 自動辞書 in raised characters (朱文), right
column first. Both sit on dark ink that fills the whole tile.

Geometry follows Android's adaptive icon grid: 108 units, of which launchers
show the middle 72, with the art inside the 72-unit circle of round masks.
The ink is its own background layer, so launchers can move the layers apart.

Fonts, downloaded into build/ on first run:
- 衡山毛筆フォント by the calligrapher Aoyagi Kouzan, for 辞. Musashi System
  distributes it free for any use, logos included:
  https://opentype.jp/kouzanmouhitufont.htm
- Shippori Mincho B1 ExtraBold (SIL Open Font License), for the seal.

The brush and seal edges are roughened with seeded noise, so every run draws
the same icon. Needs the packages in tool/requirements.txt, best in their
own environment (on this PC: D:/jidoujisho-work/.venv). Run from anywhere:

    python tool/seal_icon.py
"""
import io
import json
import os
import urllib.request
import zipfile

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
BUILD = os.path.join(APP, 'build')
SHIPPORI_URL = ('https://github.com/google/fonts/raw/main/ofl/shipporiminchob1/'
                'ShipporiMinchoB1-ExtraBold.ttf')
SHIPPORI = os.path.join(BUILD, 'ShipporiMinchoB1-ExtraBold.ttf')
KOUZAN_URL = 'https://opentype.jp/bin/KouzanMouhituFont.zip'
KOUZAN = os.path.join(BUILD, 'KouzanMouhituFont.ttf')

os.makedirs(BUILD, exist_ok=True)
if not os.path.exists(SHIPPORI):
    urllib.request.urlretrieve(SHIPPORI_URL, SHIPPORI)
if not os.path.exists(KOUZAN):
    with urllib.request.urlopen(KOUZAN_URL) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    # The name inside the zip is Shift JIS; the font is its only .ttf.
    name = next(n for n in archive.namelist() if n.lower().endswith('.ttf'))
    with open(KOUZAN, 'wb') as f:
        f.write(archive.read(name))

# The ink runs from INK_LIGHT near the top left to INK_DARK at the corners.
# INK is its tone in the middle, for places that take one colour (the
# Android 12 splash icon background in values-v31 and values-night-v31).
INK_LIGHT = (0x2B, 0x27, 0x36)
INK_DARK = (0x15, 0x13, 0x1C)
INK = (0x24, 0x20, 0x2D)
SEAL_RED = (0xEE, 0x45, 0x34)
WHITE = (255, 255, 255)
S = 24  # pixels per grid unit in the master drawing
GRID = 108
N = GRID * S


def U(v):
    return v * S


def blank():
    return Image.new('L', (N, N), 0)


def to_array(mask):
    return np.asarray(mask, np.float32) / 255


def to_mask(array):
    return Image.fromarray((np.clip(array, 0, 1) * 255).astype(np.uint8), 'L')


def noise(cell, seed, octaves=3):
    """Smooth value noise in [0, 1] with features about cell units wide."""
    rng = np.random.default_rng(seed)
    total, amp, weight = np.zeros((N, N), np.float32), 1.0, 0.0
    for octave in range(octaves):
        cells = max(2, int(GRID / cell * 2 ** octave))
        small = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8), 'L')
        total += to_array(small.resize((N, N), Image.BICUBIC)) * amp
        weight += amp
        amp /= 2
    return total / weight


def roughen(mask, amount, cell, blur, seed, holes=0.0):
    """Ink-on-paper edges: soften, push the edge with noise, threshold.

    holes leaves small unprinted specks, as a seal does."""
    a = to_array(mask.filter(ImageFilter.GaussianBlur(U(blur))))
    a -= (noise(cell, seed) - 0.5) * amount
    if holes:
        a -= np.clip((noise(0.6, seed + 9, octaves=2) - (1 - holes)) * 8, 0, 1) * 0.9
    return to_mask((a - 0.5) * 5 + 0.5)


def glyph(ch, path, size, cx, cy, bold=0.0):
    """ch centred on its ink box at (cx, cy); bold thickens strokes (units)."""
    mask = blank()
    font = ImageFont.truetype(path, int(U(size)))
    left, top, right, bottom = font.getbbox(ch)
    ImageDraw.Draw(mask).text(
        (U(cx) - (left + right) / 2, U(cy) - (top + bottom) / 2), ch, font=font, fill=255)
    if bold:
        mask = mask.filter(ImageFilter.MaxFilter(2 * round(U(bold)) + 1))
        mask = mask.filter(ImageFilter.GaussianBlur(U(0.075)))
    return mask


def marks():
    """The brush 辞 and the seal, as alpha masks on the whole grid."""
    brush = glyph('辞', KOUZAN, 47, 50.5, 51, bold=0.375)
    brush = roughen(brush, amount=0.35, cell=0.9, blur=0.15, seed=21)

    seal = blank()
    ImageDraw.Draw(seal).rounded_rectangle(
        [U(63), U(62), U(79), U(78)], radius=U(1.6), outline=255, width=int(U(1.1)))
    for ch, cx, cy in (('自', 74.8, 66.5), ('動', 74.8, 73.5),
                       ('辞', 67.2, 66.5), ('書', 67.2, 73.5)):
        seal = ImageChops.lighter(seal, glyph(ch, SHIPPORI, 6, cx, cy, bold=0.125))
    seal = roughen(seal, amount=0.42, cell=0.7, blur=0.1, seed=22, holes=0.04)
    return brush, seal


def ink():
    """The background layer: a soft radial ink gradient, dithered."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float32) / N
    t = np.clip(np.hypot(x - 0.42, y - 0.38) / 0.75, 0, 1)[..., None]
    rgb = np.array(INK_LIGHT, np.float32) * (1 - t) + np.array(INK_DARK, np.float32) * t
    rgb += np.random.default_rng(5).random((N, N, 1), np.float32) - 0.5
    alpha = np.full((N, N, 1), 255, np.float32)
    return Image.fromarray(np.clip(np.concatenate([rgb, alpha], 2), 0, 255).astype(np.uint8), 'RGBA')


def paint(layer, mask, color):
    ink_layer = Image.new('RGBA', (N, N), color + (0,))
    ink_layer.putalpha(mask)
    layer.alpha_composite(ink_layer)


def window(image, inset, px):
    """The part of the grid inside [inset, 108 - inset], scaled to px."""
    box = (int(U(inset)), int(U(inset)), int(U(GRID - inset)), int(U(GRID - inset)))
    return image.crop(box).resize((px, px), Image.LANCZOS)


def clip(image, radius=None):
    """image with its corners cut round (radius as a fraction), or as a disc."""
    size = image.size[0]
    big = Image.new('L', (size * 4, size * 4), 0)
    draw = ImageDraw.Draw(big)
    if radius is None:
        draw.ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    else:
        draw.rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=radius * size * 4, fill=255)
    out = image.convert('RGBA')
    out.putalpha(ImageChops.multiply(out.getchannel('A'), big.resize((size, size), Image.LANCZOS)))
    return out


def centred(image, px):
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((px - image.size[0]) // 2, (px - image.size[1]) // 2))
    return canvas


def save(image, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)
    return path


brush, seal = marks()
background = ink()
foreground = Image.new('RGBA', (N, N), (0, 0, 0, 0))
paint(foreground, brush, WHITE)
paint(foreground, seal, SEAL_RED)
mono = Image.new('RGBA', (N, N), (255, 255, 255, 0))
mono.putalpha(ImageChops.lighter(brush, seal))
full = background.copy()
full.alpha_composite(foreground)

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, factor in DENSITIES.items():
    # Adaptive icon layers: the whole 108 dp grid.
    px = round(108 * factor)
    save(window(background, 0, px).convert('RGB'), RES, f'drawable-{name}', 'ic_launcher_background.png')
    save(window(foreground, 0, px), RES, f'drawable-{name}', 'ic_launcher_foreground.png')
    save(window(mono, 0, px), RES, f'drawable-{name}', 'ic_launcher_monochrome.png')

    # Legacy icon for Android 7: the visible 72 dp as a 46 dp disc.
    disc = clip(window(full, 18, round(46 * factor)))
    save(centred(disc, round(48 * factor)), RES, f'mipmap-{name}', 'launcher_icon.png')

    # Android 12+ splash: the marks alone, on the INK icon background the
    # styles set; the system shows the middle 72 units as a circle.
    px = round(288 * factor)
    splash12 = window(foreground, 0, px)
    save(splash12, RES, f'drawable-{name}', 'android12splash.png')
    save(splash12, RES, f'drawable-night-{name}', 'android12splash.png')

    # Splash before Android 12: the icon as a rounded tile 112 dp wide,
    # centred in a 192 dp image.
    tile = clip(window(full, 18, round(112 * factor)), radius=0.23)
    save(centred(tile, round(192 * factor)), RES, f'drawable-{name}', 'splash.png')

# Sources kept in assets/meta, as the icon and splash generators expect.
# icon.png is also the app's own picture of its icon (the licenses page).
save(window(full, 18, 1024).convert('RGB'), APP, 'assets', 'meta', 'icon.png')
save(window(foreground, 0, 1152), APP, 'assets', 'meta', 'icon-android12.png')
save(window(mono, 0, 1152), APP, 'assets', 'meta', 'icon-monochrome.png')

# iOS: square and opaque, the ink to the edges.
ios = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
contents = json.load(open(os.path.join(ios, 'Contents.json')))
for entry in contents['images']:
    filename = entry.get('filename')
    if not filename:
        continue
    points = float(entry['size'].split('x')[0])
    scale = int(entry['scale'].rstrip('x'))
    px = round(points * scale)
    window(full, 18, px).convert('RGB').save(os.path.join(ios, filename), optimize=True)
print('done')
