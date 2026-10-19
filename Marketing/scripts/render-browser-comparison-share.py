"""Render the original comparison guide's social image using the site's Figtree.

Requires Pillow, fonttools and brotli. This is a schematic, not an app screenshot.
"""
from pathlib import Path
from tempfile import TemporaryDirectory

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'public/images/guides/browser-teleprompter-vs-iphone-app.png'
INK = '#f6edff'
LAVENDER = '#c3aaff'
MUTED = '#c4c2c8'


def render():
    image = Image.new('RGB', (1200, 630), '#0f0f0f')
    draw = ImageDraw.Draw(image)
    with TemporaryDirectory() as temporary:
        fonts = {}
        for weight in (400, 700):
            source = TTFont(ROOT / 'public/fonts/figtree-latin.woff2')
            font = instantiateVariableFont(source, {'wght': weight})
            font.flavor = None
            path = Path(temporary) / f'figtree-{weight}.ttf'
            font.save(path)
            fonts[weight] = path

        def text(position, copy, size=28, weight=400, fill=INK):
            draw.text(position, copy, font=ImageFont.truetype(str(fonts[weight]), size), fill=fill)

        def phone(x, y, width=70, height=142, script=False):
            draw.rounded_rectangle((x, y, x + width, y + height), radius=13, outline=LAVENDER, width=3)
            lens_x = x + width // 2
            draw.ellipse((lens_x - 4, y + 10, lens_x + 4, y + 18), fill=LAVENDER)
            if script:
                for offset, length in ((34, 42), (48, 35), (62, 41), (76, 29)):
                    draw.line((x + 13, y + offset, x + 13 + length, y + offset), fill=LAVENDER, width=3)

        text((64, 32), 'teleprompterpal.', 30, 700, LAVENDER)
        text((64, 94), 'Browser teleprompter', 64, 700)
        text((64, 163), 'or iPhone app?', 64, 700)
        text((67, 252), 'Start with the camera.', 32, 400, MUTED)
        draw.line((64, 322, 1136, 322), fill='#38363e', width=1)

        # Two devices: a laptop holds the words; a phone records.
        draw.rounded_rectangle((85, 388, 300, 524), radius=8, outline=LAVENDER, width=3)
        draw.line((72, 538, 313, 538), fill=LAVENDER, width=3)
        for offset, length in ((420, 148), (442, 125), (464, 142)):
            draw.line((114, offset, 114 + length, offset), fill=LAVENDER, width=3)
        phone(421, 380)
        for x in range(327, 400, 14):
            draw.line((x, 452, x + 6, 452), fill=MUTED, width=2)
        text((83, 558), 'Laptop script + iPhone camera', 25, 700)

        # One device: the words and lens share the phone, still needing a test.
        draw.line((616, 355, 616, 594), fill='#38363e', width=1)
        phone(851, 380, script=True)
        text((745, 558), 'Script + camera on iPhone', 25, 700)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == '__main__':
    render()
