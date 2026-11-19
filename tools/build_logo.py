"""Title logo from the original Paper Mario logo: the crumpled paper sheet
keeps its "PAPER", the "MARIO" (and the TM) are painted out of the paper
(inpainting) and "TETRIS" is drawn in their place in the very style of
"PAPER" (black hand-cut outline, the crumpled paper showing through the
letters), at the N64 resolution, so the whole sheet goes through the same
upscale and reads as one logo.

    python build_logo.py [--preview=file.png]
"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from sprites_lib import SRC

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "ui"
SHEET = SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Title Screen.png"
BOX = (300, 0, 490, 110)      # the Paper Mario logo on the title screen sheet
SPLIT = 46                    # rows below this hold "MARIO"
SCALE = 4
FONT = Path("C:/Windows/Fonts/ariblk.ttf")
WORD_BOX = (26, 54, 166, 87)  # where TETRIS goes on the 190x110 sheet (MARIO's place)
INK = (36, 35, 39)            # PAPER's outline colour, measured on the sheet
TETRIS_W = 0.80               # TETRIS width relative to the sheet
TETRIS_Y = 0.70               # TETRIS centre, relative to the sheet height


def paper_sheet() -> Image.Image:
    im = Image.open(SHEET).convert("RGBA").crop(BOX)
    a = np.array(im)
    rgb = a[:, :, :3].astype(np.int16)
    alpha = a[:, :, 3]
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    lum = rgb.mean(axis=2)
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # letters of MARIO: coloured or dark ink shapes that start below the
    # split. Whole shapes, not rows: the bottom outline of PAPER reaches row
    # 46-47 and must stay. Plus the TM mark.
    inside = cv2.erode((alpha > 200).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    ink = ((sat > 40) | (lum < 120)) & (alpha > 200) & inside
    n, lab, stats, _ = cv2.connectedComponentsWithStats(ink.astype(np.uint8), connectivity=8)
    mario = np.zeros_like(ink)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_TOP] >= SPLIT + 2:
            mario |= lab == i
    # their soft anti-aliased edges too, but never above the split
    mask = cv2.dilate(mario.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    mask &= inside & (yy >= SPLIT + 1)
    mask |= (xx > 160) & (yy > 40) & (yy < 60) & (lum < 170) & (alpha > 0) & inside
    # PAPER's outline right above the hole would bleed black into it: hide
    # it from the fill (as if it were blank paper), then put it back
    near = cv2.dilate(mask.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
    dark = ((lum < 170) | (sat > 40)) & inside & near & ~mask
    bgr = cv2.cvtColor(a[:, :, :3], cv2.COLOR_RGB2BGR)
    fixed = cv2.inpaint(bgr, (mask | dark).astype(np.uint8) * 255, 4, cv2.INPAINT_TELEA)
    rgb_fixed = cv2.cvtColor(fixed, cv2.COLOR_BGR2RGB)
    a[:, :, :3] = np.where(mask[:, :, None], rgb_fixed, a[:, :, :3])
    draw_word(a, "TETRIS")
    im = Image.fromarray(a, "RGBA")
    # upscale (premultiplied, so the transparent border does not go dark)
    pm = np.array(im).astype(np.float32) / 255.0
    pm[:, :, :3] *= pm[:, :, 3:4]
    big = []
    for c in range(4):
        ch = Image.fromarray((pm[:, :, c] * 255).astype(np.uint8), "L")
        big.append(np.array(ch.resize((w * SCALE, h * SCALE), Image.LANCZOS)).astype(np.float32) / 255.0)
    big = np.stack(big, axis=2)
    al = np.clip(big[:, :, 3:4], 1e-4, 1)
    big[:, :, :3] = np.clip(big[:, :, :3] / al, 0, 1)
    out = Image.fromarray((np.clip(big, 0, 1) * 255).astype(np.uint8), "RGBA")
    return out.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))


def draw_word(a: np.ndarray, word: str, ss: int = 8):
    """Draws `word` onto the sheet pixels like PAPER: chunky letters, each a
    little tilted and off the line as if cut by hand, a ~2 px black outline
    and the paper itself (slightly whitened) as the fill."""
    x0, y0, x1, y1 = WORD_BOX
    bw, bh = (x1 - x0) * ss, (y1 - y0) * ss
    font = ImageFont.truetype(str(FONT), int(bh * 1.32))
    rng = np.random.default_rng(64)
    glyphs = []
    for ch in word:
        box = font.getbbox(ch)
        g = Image.new("L", (box[2] - box[0] + 8 * ss, box[3] - box[1] + 8 * ss), 0)
        ImageDraw.Draw(g).text((4 * ss - box[0], 4 * ss - box[1]), ch, font=font, fill=255)
        g = g.rotate(float(rng.uniform(-4, 4)), resample=Image.BICUBIC, expand=False)
        glyphs.append(g)
    gap = int(1.5 * ss)
    total = sum(g.width - 8 * ss for g in glyphs) + gap * (len(glyphs) - 1)
    k = min(1.0, bw / total)
    layer = Image.new("L", (bw + 16 * ss, bh + 16 * ss), 0)
    x = 8 * ss + (bw - total * k) / 2
    for g in glyphs:
        gs = g.resize((max(1, int(g.width * k)), max(1, int(g.height * k * (bh / (g.height - 8 * ss)) / k))), Image.LANCZOS)
        dy = int(rng.uniform(-1.2, 1.2) * ss)
        layer.paste(gs, (int(x - 4 * ss * k), 8 * ss - 4 * ss + dy), gs)
        x += (g.width - 8 * ss) * k + gap
    body = np.asarray(layer).astype(np.float32) / 255.0
    # hand-cut edges: the outline wobbles a little
    outline = np.asarray(layer.filter(ImageFilter.MaxFilter(2 * int(2.2 * ss) + 1))).astype(np.float32) / 255.0
    noise = np.asarray(Image.fromarray((rng.random((outline.shape[0] // ss + 1, outline.shape[1] // ss + 1)) * 255)
                                       .astype(np.uint8)).resize((outline.shape[1], outline.shape[0]), Image.BICUBIC)).astype(np.float32) / 255.0
    outline = np.clip(outline * (0.85 + 0.3 * noise), 0, 1)
    # down to the sheet's pixels
    def down(m):
        w, h = m.shape[1] // ss, m.shape[0] // ss
        return m[:h * ss, :w * ss].reshape(h, ss, w, ss).mean(axis=(1, 3))
    body, outline = down(body), down(outline)
    oy, ox = y0 - 8, x0 - 8
    h, w = body.shape
    reg = a[oy:oy + h, ox:ox + w]
    alpha = reg[:, :, 3:4].astype(np.float32) / 255.0
    rgb = reg[:, :, :3].astype(np.float32)
    ink_a = np.clip(outline * 1.15, 0, 1)[:, :, None] * (alpha > 0.5)
    rgb = rgb * (1 - ink_a) + np.array(INK, np.float32) * ink_a
    # the fill: the paper underneath, whitened and cooled like PAPER's
    fill = np.clip(body * 1.2 - 0.1, 0, 1)[:, :, None] * (alpha > 0.5)
    paper = reg[:, :, :3].astype(np.float32)
    lit = paper * 0.55 + np.array([214, 214, 222], np.float32) * 0.45
    rgb = rgb * (1 - fill) + lit * fill
    reg[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)


def main():
    sheet = paper_sheet()
    sheet.save(OUT / "logo_paper.png")
    print("logo_paper.png", sheet.size)
    for arg in sys.argv[1:]:
        if arg.startswith("--preview="):
            tet = Image.open(OUT / "logo_tetris.png").convert("RGBA")
            tw = int(sheet.width * TETRIS_W)
            tet = tet.resize((tw, int(tet.height * tw / tet.width)), Image.LANCZOS)
            prev = Image.new("RGBA", (sheet.width + 40, sheet.height + 40), (120, 160, 200, 255))
            prev.alpha_composite(sheet, (20, 20))
            prev.alpha_composite(tet, (20 + (sheet.width - tw) // 2, 20 + int(sheet.height * TETRIS_Y) - tet.height // 2))
            prev.save(arg.split("=", 1)[1])


if __name__ == "__main__":
    main()
