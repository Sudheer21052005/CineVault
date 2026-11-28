"""Rasterize the source CineVault emblem into the shipped launcher assets."""

import argparse
import base64
from io import BytesIO
from pathlib import Path

from PIL import Image
from phase1_web_benchmark import chrome, serve


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    with serve(root / 'assets/images/branding', False) as origin, chrome(args.chrome, origin, False) as browser:
        browser.open()
        browser.evaluate("""window.raster = new Image(); raster.src = 'cinevault_emblem.svg'; true""")
        browser.wait(lambda: browser.evaluate('raster.complete && raster.naturalWidth > 0'), 'source SVG')
        data = browser.evaluate("""(() => {
          const canvas = document.createElement('canvas');
          canvas.width = canvas.height = 1024;
          canvas.getContext('2d').drawImage(raster, 0, 0, 1024, 1024);
          return canvas.toDataURL('image/png').split(',')[1];
        })()""")
    emblem = Image.open(BytesIO(base64.b64decode(data))).convert('RGBA')

    def raster(size, *, maskable=False):
        if not maskable:
            return emblem.resize((size, size), Image.Resampling.LANCZOS)
        side = round(size * .79)
        inset = (size - side) // 2
        tile = Image.new('RGBA', (size, size), '#0A1121')
        tile.alpha_composite(emblem.resize((side, side), Image.Resampling.LANCZOS), (inset, inset))
        return tile

    raster(48).save(root / 'web/favicon.png')
    for size in (192, 512):
        raster(size).save(root / f'web/icons/Icon-{size}.png')
        raster(size, maskable=True).save(root / f'web/icons/Icon-maskable-{size}.png')
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        raster(size).save(root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    raster(256).save(root / 'windows/runner/resources/app_icon.ico', sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)])


if __name__ == '__main__':
    main()
