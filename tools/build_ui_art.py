"""UI art for Paper Tetris: paper blocks, cardboard windows, logo, particles.

Everything is drawn at 4x then downsampled for clean anti-aliased edges,
with a light paper grain so it sits well next to the Paper Mario sprites.
"""
import colorsys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "ui"
SS = 4
CELL = 44

PIECES = {
    "I": "3ec6ee", "O": "ffd23f", "T": "b05ce0", "S": "5cc83c",
    "Z": "ec4a3c", "J": "3e6ee8", "L": "f68a2e", "X": "9aa0a8",
}


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, light=0.0, sat=0.0):
    r, g, b = [c / 255 for c in rgb]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = min(max(l + light, 0), 1)
    s = min(max(s + sat, 0), 1)
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return (int(r * 255), int(g * 255), int(b * 255))


def grain(size, strength=10, seed=0, scale=1):
    rng = np.random.default_rng(seed)
    w, h = size
    n = rng.normal(0, 1, (h // scale + 1, w // scale + 1))
    img = Image.fromarray(np.uint8(np.clip(128 + n * strength, 0, 255)), "L")
    if scale > 1:
        img = img.resize((w, h), Image.BILINEAR)
    return img.crop((0, 0, w, h))


def apply_grain(img, strength=7, seed=0):
    """Multiply-ish paper fibre noise on the RGB channels, alpha kept."""
    a = np.array(img).astype(np.float32)
    g = np.array(grain(img.size, strength, seed)).astype(np.float32) - 128
    # fibres: stretch some noise horizontally
    fib = np.array(grain((img.size[0] // 6 + 1, img.size[1]), strength * 0.8, seed + 1)
                   .resize(img.size, Image.BILINEAR)).astype(np.float32) - 128
    a[:, :, :3] += (g * 0.6 + fib * 0.6)[:, :, None]
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), "RGBA")


def down(img, size):
    return img.resize(size, Image.LANCZOS)


# ------------------------------------------------------------------ blocks

def block(color_hex, size=CELL):
    S = size * SS
    base = hexrgb(color_hex)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 7 * SS
    outline = shade(base, -0.33, 0.05)
    d.rounded_rectangle([0, 0, S - 1, S - 1], r, fill=outline + (255,))
    # body gradient
    inset = int(2.2 * SS)
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    top, bot = shade(base, 0.07), shade(base, -0.08)
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        gd.line([(0, y), (S, y)], fill=c + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([inset, inset, S - 1 - inset, S - 1 - inset], r - inset, fill=255)
    body.paste(grad, (0, 0), mask)
    img.alpha_composite(body)
    # bevel: light top-left band, dark bottom-right band
    bev = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bev)
    w = int(3.2 * SS)
    hl = shade(base, 0.22, -0.05)
    dk = shade(base, -0.2)
    bd.rounded_rectangle([inset, inset, S - 1 - inset, S - 1 - inset], r - inset, outline=dk + (255,), width=w)
    hl_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl_mask).polygon([(0, 0), (S, 0), (0, S)], fill=255)
    hl_band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl_band).rounded_rectangle([inset, inset, S - 1 - inset, S - 1 - inset], r - inset,
                                              outline=hl + (255,), width=w)
    bev.paste(hl_band, (0, 0), ImageChops.multiply(hl_mask, hl_band.split()[3]))
    img.alpha_composite(bev)
    # glossy paper shine
    shine = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    sd.rounded_rectangle([int(S * 0.2), int(S * 0.16), int(S * 0.52), int(S * 0.3)], int(S * 0.07),
                         fill=(255, 255, 255, 150))
    sd.ellipse([int(S * 0.58), int(S * 0.17), int(S * 0.68), int(S * 0.28)], fill=(255, 255, 255, 120))
    img.alpha_composite(shine)
    out = down(img, (size, size))
    return apply_grain(out, 5, seed=hash(color_hex) % 1000)


def ghost(size=CELL):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 7 * SS
    d.rounded_rectangle([SS, SS, S - 1 - SS, S - 1 - SS], r, fill=(255, 255, 255, 50),
                        outline=(255, 255, 255, 235), width=int(3 * SS))
    # dashed inner stitch like a pencil outline
    for k in range(4):
        x0 = int(S * (0.18 + k * 0.18))
        d.line([(x0, int(S * 0.5)), (x0 + int(S * 0.08), int(S * 0.5))], fill=(255, 255, 255, 90), width=SS * 2)
    return down(img, (size, size))


def cell_flash(size=CELL):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, S - 1, S - 1], 7 * SS, fill=(255, 255, 255, 255))
    return down(img, (size, size))


# ------------------------------------------------------------------ panels

def panel(fill="f8eed2", border="4a2f1c", inner="fffaf0", size=160, radius=26, bw=5, name="panel_paper"):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius * SS, fill=hexrgb(border) + (255,))
    i = bw * SS
    d.rounded_rectangle([i, i, S - 1 - i, S - 1 - i], (radius - bw) * SS, fill=hexrgb(fill) + (255,))
    # inner highlight line (cut paper edge)
    j = i + int(2.5 * SS)
    d.rounded_rectangle([j, j, S - 1 - j, S - 1 - j], (radius - bw - 2) * SS,
                        outline=hexrgb(inner) + (200,), width=int(1.6 * SS))
    out = down(img, (size, size))
    out = apply_grain(out, 7, seed=len(name))
    out.save(OUT / f"{name}.png")


def shadow_patch(size=160, radius=26, blur=14, name="panel_shadow", alpha=110):
    pad = blur * 2
    S = size + pad * 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([pad, pad, pad + size - 1, pad + size - 1], radius,
                                          fill=(40, 22, 10, alpha))
    img = img.filter(ImageFilter.GaussianBlur(blur))
    img.save(OUT / f"{name}.png")


def tab(color="d8402c", size=(120, 56), radius=18, name="tab_red"):
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = hexrgb(color)
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius * SS, fill=shade(base, -0.3) + (255,))
    i = 4 * SS
    d.rounded_rectangle([i, i, w * SS - 1 - i, h * SS - 1 - i], (radius - 4) * SS, fill=base + (255,))
    d.rounded_rectangle([i + 2 * SS, i + 2 * SS, w * SS - 1 - i - 2 * SS, int(h * SS * 0.45)],
                        (radius - 6) * SS, fill=shade(base, 0.12) + (255,))
    out = down(img, size)
    apply_grain(out, 6, seed=3).save(OUT / f"{name}.png")


def board_frame():
    """Cardboard frame around the well, 9-slice (margins 36)."""
    size = 200
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], 30 * SS, fill=(58, 36, 20, 255))
    d.rounded_rectangle([5 * SS, 5 * SS, S - 1 - 5 * SS, S - 1 - 5 * SS], 26 * SS, fill=(246, 234, 204, 255))
    d.rounded_rectangle([9 * SS, 9 * SS, S - 1 - 9 * SS, S - 1 - 9 * SS], 22 * SS, outline=(255, 252, 240, 210),
                        width=2 * SS)
    # inner opening (transparent) with dark lip
    o = 22 * SS
    d.rounded_rectangle([o - 4 * SS, o - 4 * SS, S - 1 - o + 4 * SS, S - 1 - o + 4 * SS], 14 * SS,
                        fill=(58, 36, 20, 255))
    d.rounded_rectangle([o, o, S - 1 - o, S - 1 - o], 10 * SS, fill=(0, 0, 0, 0))
    out = down(img, (size, size))
    apply_grain(out, 7, seed=9).save(OUT / "board_frame.png")


def well_shading():
    """Soft inner shadow for the board well (stretched)."""
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    a = np.zeros((size, size), np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    edge = np.minimum(np.minimum(xx, size - 1 - xx), np.minimum(yy, size - 1 - yy)).astype(np.float32)
    a = np.clip(1.0 - edge / 22.0, 0, 1) ** 2 * 120
    arr = np.zeros((size, size, 4), np.uint8)
    arr[:, :, :3] = (10, 8, 30)
    arr[:, :, 3] = a.astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / "well_shade.png")


# ------------------------------------------------------------------ logo

LETTERS = {
    "T": ["#####", "..#..", "..#..", "..#..", "..#.."],
    "E": ["####", "#...", "###.", "#...", "####"],
    "R": ["####.", "#...#", "####.", "#..#.", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "S": [".####", "#....", ".###.", "....#", "####."],
}


def fill_holes(mask):
    """Fill enclosed transparent holes of a binary mask (flood from outside)."""
    m = np.array(mask) > 0
    h, w = m.shape
    outside = np.zeros_like(m)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not m[y, x] and not outside[y, x]:
            outside[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    return Image.fromarray(np.uint8(~outside) * 255, "L")


# ------------------------------------------------------------------ misc

def misc():
    # actor shadow
    s = Image.new("RGBA", (96 * SS, 32 * SS), (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse([4 * SS, 4 * SS, 92 * SS, 28 * SS], fill=(30, 18, 10, 120))
    s = s.filter(ImageFilter.GaussianBlur(3 * SS))
    down(s, (96, 32)).save(OUT / "shadow.png")
    # confetti paper bit (white, tinted in Godot)
    c = Image.new("RGBA", (12 * SS, 8 * SS), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle([0, 0, 12 * SS - 1, 8 * SS - 1], SS, fill=(255, 255, 255, 255),
                                        outline=(200, 200, 200, 255), width=SS)
    down(c, (12, 8)).save(OUT / "confetti.png")
    # soft round glow
    g = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    a = np.zeros((128, 128), np.float32)
    yy, xx = np.mgrid[0:128, 0:128]
    rr = np.sqrt((xx - 63.5) ** 2 + (yy - 63.5) ** 2) / 64
    arr = np.zeros((128, 128, 4), np.uint8)
    arr[:, :, :3] = 255
    arr[:, :, 3] = (np.clip(1 - rr, 0, 1) ** 2 * 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / "glow.png")
    # vignette for the whole screen
    W, H = 480, 270
    yy, xx = np.mgrid[0:H, 0:W]
    v = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    arr = np.zeros((H, W, 4), np.uint8)
    arr[:, :, :3] = (30, 15, 5)
    arr[:, :, 3] = (np.clip((v - 0.65) / 0.75, 0, 1) ** 1.6 * 150).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / "vignette.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for k, c in PIECES.items():
        block(c).save(OUT / f"block_{k}.png")
        block(c, 26).save(OUT / f"block_{k}_small.png")
    ghost().save(OUT / "block_ghost.png")
    cell_flash().save(OUT / "block_flash.png")
    panel()
    panel(fill="fdf6e3", border="4a2f1c", inner="ffffff", name="panel_light")
    panel(fill="2f2350", border="160f2a", inner="5a4a8a", name="panel_night")
    shadow_patch()
    tab("d8402c", name="tab_red")
    tab("e8a020", name="tab_gold")
    tab("3a7bd8", name="tab_blue")
    tab("4aa848", name="tab_green")
    tab("8a5cc8", name="tab_purple")
    board_frame()
    well_shading()
    misc()
    print("ui art ok")


if __name__ == "__main__":
    main()
