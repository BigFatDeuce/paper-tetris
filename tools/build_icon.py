"""Game / app icon: a big pixel Shy Guy, cut out like a Paper Mario sticker,
in front of a little Tetris stack under the starry Paper Mario sky of
Shooting Star Summit.

The Shy Guy is the 14 x 14 portrait in tools/shyguy_icon.png (its green and
blue background pixels are dropped). Writes game/icon.png (project, window
and web icon), game/icon.ico (Windows), the Android adaptive layers
(game/assets/icon/android_*.png), the Linux desktop icons
(tools/linux/icons/paper-tetris_<n>.png) and store-size previews into
dist/icon/.

    python build_icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
TOOLS = ROOT / "tools"
PORTRAIT = TOOLS / "shyguy_icon.png"
BACKDROP = [(0x94, 0xc5, 0x00), (0x00, 0x63, 0xa3)]   # green and blue around him
S = 1024
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def sky(size: int) -> Image.Image:
    # the starry Paper Mario battle sky of the Shooting Star Summit stage
    im = Image.open(GAME / "assets" / "stages" / "stars" / "sky.png").convert("RGB")
    w, h = im.size
    im = im.crop((w // 2 - h // 2, 0, w // 2 + h // 2, h))
    return im.resize((size, size), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 50, 2)).convert("RGBA")


def shyguy() -> Image.Image:
    """The portrait with its background made transparent (1 px per pixel)."""
    a = np.asarray(Image.open(PORTRAIT).convert("RGBA")).copy()
    for c in BACKDROP:
        a[(a[..., :3] == c).all(2), 3] = 0
    return Image.fromarray(a, "RGBA")


def sticker(img: Image.Image, outline: int, shadow: int) -> Image.Image:
    """Paper cut-out: a white paper margin, a thin ink edge and a soft shadow."""
    pad = outline + shadow * 3
    w, h = img.width + pad * 2, img.height + pad * 2
    alpha = Image.new("L", (w, h), 0)
    alpha.paste(img.getchannel("A"), (pad, pad))
    # round dilation: blur then threshold keeps the corners soft like cut paper
    paper = alpha.filter(ImageFilter.GaussianBlur(outline * 0.6)).point(lambda v: 255 if v > 18 else 0)
    paper = paper.filter(ImageFilter.MaxFilter(_odd(outline * 0.9)))
    ink = paper.filter(ImageFilter.MaxFilter(_odd(max(3, outline * 0.25))))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (10, 6, 30, 0))
    sh.putalpha(ink.point(lambda v: 120 if v else 0).filter(ImageFilter.GaussianBlur(shadow)))
    out.alpha_composite(sh, (shadow // 2, shadow))
    edge = Image.new("RGBA", (w, h), (58, 32, 16, 0))
    edge.putalpha(ink)
    out.alpha_composite(edge)
    white = Image.new("RGBA", (w, h), (252, 249, 238, 0))
    white.putalpha(paper)
    out.alpha_composite(white)
    out.alpha_composite(img, (pad, pad))
    return out, pad


def _odd(v: float) -> int:
    v = int(round(v))
    return v + 1 if v % 2 == 0 else v


def block(kind: str, px: int) -> Image.Image:
    b = Image.open(GAME / "assets" / "ui" / f"block_{kind}.png").convert("RGBA")
    return b.resize((px, px), Image.LANCZOS)


def scene(size: int, with_sky=True, guy_cell=None) -> Image.Image:
    k = size / S
    out = sky(size) if with_sky else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell = int(128 * k)
    row_y = size - cell - int(46 * k)               # top of the stack row
    if with_sky:
        # a falling T piece in the top left corner, where his hood leaves room
        bc = int(78 * k)
        for dx, dy in [(0, 0), (1, 0), (2, 0), (1, 1)]:
            out.alpha_composite(block("T", bc), (int(70 * k) + dx * bc, int(62 * k) + dy * bc))
    px = guy_cell or max(1, int(round(54 * k)))
    g = shyguy()
    g = g.resize((g.width * px, g.height * px), Image.NEAREST)
    st, pad = sticker(g, max(2, int(22 * k)), max(1, int(12 * k)))
    gx = (size - g.width) // 2 + int(30 * k) - pad
    if with_sky:
        # he peeks over a row of Tetris pieces, hands resting on it
        gy = row_y - int(12.4 * px) - pad
    else:
        gy = size - g.height - pad
    out.alpha_composite(st, (gx, gy))
    if with_sky:
        x0 = (size - cell * 8) // 2
        sh = Image.new("RGBA", (cell * 8, int(24 * k)), (10, 6, 30, 90)).filter(ImageFilter.GaussianBlur(8 * k))
        out.alpha_composite(sh, (x0, row_y - int(10 * k)))
        for rx, ch in enumerate("JZZSSTOI"):
            out.alpha_composite(block(ch, cell), (x0 + rx * cell, row_y))
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
    cream.putalpha(mask.filter(ImageFilter.MinFilter(_odd(rim / 3 * 2 + 1))))
    out.alpha_composite(cream)
    pic = img.copy()
    pic.putalpha(Image.fromarray(np.minimum(np.array(inner), np.array(img.getchannel("A")))))
    out.alpha_composite(pic)
    return out


def small(n: int) -> Image.Image:
    """Tiny sizes: the portrait itself, pixel for pixel, on a sky tile."""
    k = n // 16                                     # 1x at 16, 2x at 32, 3x at 48
    tile = rounded(sky(n * 8), n * 8 * 0.19, int(n * 8 * 0.06)).resize((n, n), Image.LANCZOS)
    g = shyguy()
    g = g.resize((14 * k, 14 * k), Image.NEAREST)
    tile.alpha_composite(g, ((n - g.width) // 2, n - g.height - k))
    return tile


def main():
    icon = rounded(scene(S), 190, 36)
    icon.save(GAME / "icon.png")
    sizes = [256, 128, 64, 48, 32, 16]
    frames = [icon.resize((n, n), Image.LANCZOS) if n > 48 else small(n) for n in sizes]
    frames[0].save(GAME / "icon.ico", sizes=[(n, n) for n in sizes], append_images=frames[1:])
    adir = GAME / "assets" / "icon"
    adir.mkdir(parents=True, exist_ok=True)
    # Android adaptive icon: 432 px layers, the launcher masks the outer third
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(scene(288, with_sky=False, guy_cell=16), (72, 72))
    fg.save(adir / "android_foreground.png")
    bg = sky(432)
    bg.save(adir / "android_background.png")
    icon.resize((192, 192), Image.LANCZOS).save(adir / "android_main.png")
    ldir = TOOLS / "linux" / "icons"
    ldir.mkdir(parents=True, exist_ok=True)
    for n in LINUX_SIZES:
        (icon.resize((n, n), Image.LANCZOS) if n > 48 else small(n)).save(ldir / f"paper-tetris_{n}.png")
    icon.resize((256, 256), Image.LANCZOS).save(ROOT / "docs" / "icon.png")
    dist = ROOT / "dist" / "icon"
    dist.mkdir(parents=True, exist_ok=True)
    for n in (1024, 512, 256):
        icon.resize((n, n), Image.LANCZOS).save(dist / f"paper_tetris_{n}.png")
    print("icon written")


if __name__ == "__main__":
    main()
