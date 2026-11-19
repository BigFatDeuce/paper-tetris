"""Game / app icon: Groove Guy striking his disco pose on a stack of Tetris
blocks, under the starry Paper Mario sky of Shooting Star Summit.

Writes game/icon.png (project + web icon), game/icon.ico (Windows), the
Android adaptive layers (game/assets/icon/android_*.png) and store-size
previews into dist/icon/.

    python build_icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
GROOVE = GAME / "assets" / "sprites" / "characters" / "groove_guy.png"
CELL = 51
POSE = 11                              # disco point, arm up
S = 1024


def sky(size: int) -> Image.Image:
    # the starry Paper Mario battle sky of the Shooting Star Summit stage
    im = Image.open(GAME / "assets" / "stages" / "stars" / "sky.png").convert("RGB")
    w, h = im.size
    im = im.crop((w // 2 - h // 2, 0, w // 2 + h // 2, h))
    return im.resize((size, size), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 50, 2)).convert("RGBA")


def sprite(img: Image.Image, scale: int) -> Image.Image:
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def groove(scale: int) -> Image.Image:
    sheet = Image.open(GROOVE).convert("RGBA")
    cols = sheet.width // CELL
    x, y = (POSE % cols) * CELL, (POSE // cols) * CELL
    cell = sheet.crop((x, y, x + CELL, y + CELL))
    return sprite(cell.crop(cell.getbbox()), scale)


def block(kind: str, px: int) -> Image.Image:
    b = Image.open(GAME / "assets" / "ui" / f"block_{kind}.png").convert("RGBA")
    return b.resize((px, px), Image.LANCZOS)


def scene(size: int, with_sky=True, with_stack=True, with_guy=True) -> Image.Image:
    k = size / S
    out = sky(size) if with_sky else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if with_stack:
        cell = int(118 * k)
        # a little Tetris stack with a gap, the way the game looks mid-run
        rows = ["JJLLOO.TTI", "ZZSLOOTTTI", "IZSSL.JJJI"]
        rows = [r[1:9] for r in rows]          # 8 columns fit the icon
        x0 = (size - cell * 8) // 2
        y0 = size - cell * len(rows) - int(40 * k)
        for ry, row in enumerate(rows):
            for rx, ch in enumerate(row):
                if ch != ".":
                    out.alpha_composite(block(ch, cell), (x0 + rx * cell, y0 + ry * cell))
        # a falling T piece, top right
        for dx, dy in [(0, 0), (1, 0), (2, 0), (1, 1)]:
            out.alpha_composite(block("T", cell), (int(590 * k) + dx * cell, int(70 * k) + dy * cell))
    if with_guy:
        g = groove(max(1, int(round(12 * k))))
        shadow = Image.new("RGBA", g.size, (0, 0, 0, 0))
        shadow.putalpha(g.getchannel("A").point(lambda v: 110 if v else 0))
        shadow = shadow.filter(ImageFilter.GaussianBlur(10 * k))
        gx = int(150 * k)
        gy = size - int(40 * k) - int(118 * k) * 3 - g.height + int(6 * k)   # feet on the stack
        out.alpha_composite(shadow, (gx + int(14 * k), gy + int(14 * k)))
        out.alpha_composite(g, (gx, gy))
    return out


def rounded(img: Image.Image, radius: float, rim: int) -> Image.Image:
    size = img.width
    ss = 4
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * ss - 1, size * ss - 1], radius * ss, fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    inner = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(inner).rounded_rectangle([rim * ss, rim * ss, (size - rim) * ss - 1, (size - rim) * ss - 1],
                                            (radius - rim) * ss, fill=255)
    inner = inner.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    frame = Image.new("RGBA", (size, size), (58, 32, 16, 255))     # dark ink rim
    frame.putalpha(mask)
    out.alpha_composite(frame)
    cream = Image.new("RGBA", (size, size), (250, 243, 222, 255))  # paper border
    ring = ImageChops_sub(mask, rim // 3)
    cream.putalpha(ring)
    out.alpha_composite(cream)
    pic = img.copy()
    pic.putalpha(Image.fromarray(np.minimum(np.array(inner), np.array(img.getchannel("A")))))
    out.alpha_composite(pic)
    return out


def ImageChops_sub(mask: Image.Image, px: int) -> Image.Image:
    return mask.filter(ImageFilter.MinFilter(px * 2 + 1)) if px > 0 else mask


def main():
    icon = rounded(scene(S), 190, 36)
    icon.save(GAME / "icon.png")
    icon.resize((256, 256), Image.LANCZOS).save(
        GAME / "icon.ico", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    adir = GAME / "assets" / "icon"
    adir.mkdir(parents=True, exist_ok=True)
    # Android adaptive icon: 432 px layers, the launcher masks the outer third
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    content = scene(288, with_sky=False)
    fg.alpha_composite(content, (72, 72))
    fg.save(adir / "android_foreground.png")
    sky(432).save(adir / "android_background.png")
    icon.resize((192, 192), Image.LANCZOS).save(adir / "android_main.png")
    dist = ROOT / "dist" / "icon"
    dist.mkdir(parents=True, exist_ok=True)
    for n in (1024, 512, 256):
        icon.resize((n, n), Image.LANCZOS).save(dist / f"paper_tetris_{n}.png")
    print("icon written")


if __name__ == "__main__":
    main()
