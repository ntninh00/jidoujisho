"""Draws the 辞 seal icon and writes every launcher icon and splash image.

Geometry follows Android's adaptive icon grid: 108 units, of which launchers
show the middle 72, with art kept inside the 66-unit safe circle. The seal is
a 46-unit rounded square turned 5 degrees, with the kanji in white.

The kanji is set in Shippori Mincho B1 ExtraBold (SIL Open Font License),
downloaded on first run. Needs Pillow. Run from anywhere:

    python tool/seal_icon.py
"""
import json
import os
import urllib.request

from PIL import Image, ImageDraw, ImageFont

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
FONT_URL = ('https://github.com/google/fonts/raw/main/ofl/shipporiminchob1/'
            'ShipporiMinchoB1-ExtraBold.ttf')
FONT = os.path.join(APP, 'build', 'ShipporiMinchoB1-ExtraBold.ttf')

if not os.path.exists(FONT):
    os.makedirs(os.path.dirname(FONT), exist_ok=True)
    urllib.request.urlretrieve(FONT_URL, FONT)

RED = (0xF4, 0x43, 0x36, 255)
WHITE = (255, 255, 255, 255)
S = 40  # pixels per grid unit in the master drawing
GRID = 108


def rounded(draw, box, radius, **kwargs):
    draw.rounded_rectangle([v * S for v in box], radius=radius * S, **kwargs)


def master(mono=False):
    """The seal on a transparent 108-unit canvas."""
    size = GRID * S
    if mono:
        # Alpha only: the seal with the border and kanji cut out.
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        rounded(draw, (31, 31, 77, 77), 9, fill=255)
        rounded(draw, (34.8, 34.8, 73.2, 73.2), 6, outline=0, width=int(1.5 * S))
        glyph(draw, 0)
        layer = Image.new('RGBA', (size, size), (255, 255, 255, 0))
        layer.putalpha(mask)
    else:
        layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        rounded(draw, (31, 31, 77, 77), 9, fill=RED)
        rounded(draw, (34.8, 34.8, 73.2, 73.2), 6, outline=WHITE, width=int(1.5 * S))
        glyph(draw, WHITE)
    return layer.rotate(5, resample=Image.BICUBIC, center=(size / 2, size / 2))


def glyph(draw, fill):
    font = ImageFont.truetype(FONT, int(30 * S))
    left, top, right, bottom = font.getbbox('辞')
    x = 54 * S - (left + right) / 2
    y = 54.3 * S - (top + bottom) / 2
    draw.text((x, y), '辞', font=font, fill=fill)


def window(image, inset, px):
    """The part of the grid inside [inset, 108 - inset], scaled to px."""
    box = (int(inset * S), int(inset * S), int((GRID - inset) * S), int((GRID - inset) * S))
    return image.crop(box).resize((px, px), Image.LANCZOS)


def on_background(image, color, circle=False):
    base = Image.new('RGBA', image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)
    if circle:
        draw.ellipse((0, 0, image.size[0] - 1, image.size[1] - 1), fill=color)
    else:
        draw.rectangle((0, 0, image.size[0], image.size[1]), fill=color)
    base.alpha_composite(image)
    if circle:
        mask = Image.new('L', image.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, image.size[0] - 1, image.size[1] - 1), fill=255)
        base.putalpha(Image.composite(base.getchannel('A'), mask, mask))
    return base


def save(image, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)
    return path


color = master()
mono = master(mono=True)
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

for name, factor in DENSITIES.items():
    # Adaptive icon layers: the whole 108 dp grid.
    px = round(108 * factor)
    save(window(color, 0, px), RES, f'drawable-{name}', 'ic_launcher_foreground.png')
    save(window(mono, 0, px), RES, f'drawable-{name}', 'ic_launcher_monochrome.png')

    # Legacy icon for Android 7: a white disc with the visible 72 dp of the grid.
    px = round(48 * factor)
    inner = round(46 * factor)
    disc = on_background(window(color, 18, inner), WHITE, circle=True)
    legacy = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    legacy.alpha_composite(disc, ((px - inner) // 2, (px - inner) // 2))
    save(legacy, RES, f'mipmap-{name}', 'launcher_icon.png')

    # Android 12+ splash icon, same geometry as the foreground layer.
    px = round(288 * factor)
    splash12 = window(color, 0, px)
    save(splash12, RES, f'drawable-{name}', 'android12splash.png')
    save(splash12, RES, f'drawable-night-{name}', 'android12splash.png')

    # Splash before Android 12: a 192 dp image with the seal about 100 dp wide.
    px = round(192 * factor)
    save(window(color, 54 - 46 * 192 / 100 / 2, px), RES, f'drawable-{name}', 'splash.png')

# Sources kept in assets/meta, as the icon and splash generators expect.
save(window(color, 18, 1024), APP, 'assets', 'meta', 'icon.png')
save(window(color, 0, 1152), APP, 'assets', 'meta', 'icon-android12.png')
save(window(mono, 0, 1152), APP, 'assets', 'meta', 'icon-monochrome.png')

# iOS: square, opaque, white behind the seal.
ios = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
contents = json.load(open(os.path.join(ios, 'Contents.json')))
for entry in contents['images']:
    filename = entry.get('filename')
    if not filename:
        continue
    points = float(entry['size'].split('x')[0])
    scale = int(entry['scale'].rstrip('x'))
    px = round(points * scale)
    square = on_background(window(color, 18, px), WHITE).convert('RGB')
    square.save(os.path.join(ios, filename), optimize=True)
print('done')
