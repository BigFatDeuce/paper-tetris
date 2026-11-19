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
from PIL import Image, ImageDraw, ImageFilter

from sprites_lib import SRC

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "ui"
SHEET = SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Title Screen.png"
BOX = (300, 0, 490, 110)      # the Paper Mario logo on the title screen sheet
SPLIT = 46                    # rows below this hold "MARIO"
SCALE = 4
INK = (36, 35, 39)            # PAPER's outline colour, measured on the sheet
TETRIS_W = 0.80               # TETRIS width relative to the sheet
TETRIS_Y = 0.70               # TETRIS centre, relative to the sheet height


def paper_sheet() -> Image.Image:
    im = Image.open(SHEET).convert("RGBA").crop(BOX)
    a = np.array(im)
    src = a.copy()
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
    draw_word(a, src)
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


# TETRIS on the sheet. E and R are lifted pixel for pixel from PAPER
# (src box on the 190x110 sheet); T, I and S are drawn the way PAPER is:
# thin hand-drawn ink lines (outline polygons in sheet pixels, 37 px tall
# like PAPER's letters) on the bare paper.
COPIED = {"E": (100, 6, 132, 48), "R": (126, 6, 156, 48)}
DRAWN = {
    "T": [(0, 1), (23, 0), (23.5, 9), (15.5, 9.5), (16, 37), (7.5, 37), (8, 9.5), (0, 10)],
    "I": [(0, 0.5), (9.5, 0), (10, 37), (0.5, 37)],
    "S": [(0.5, 0.5), (21.5, 0), (21, 8.5), (9.5, 8.5), (9.5, 13.5), (21, 13.5), (22, 37), (0, 37),
          (0, 28.5), (12.5, 28.5), (12, 22), (0.5, 22)],
}
WORD = [("T", 0), ("E", 1), ("T", 1), ("R", 1), ("I", 2), ("S", 2)]   # letter, gap before
WORD_Y = 51


def _letter_mask(patch_ink: np.ndarray) -> np.ndarray:
    """Inside of a hand-drawn letter: everything the outside cannot reach."""
    free = (~patch_ink).astype(np.uint8)
    h, w = free.shape
    pad = np.pad(free, 1, constant_values=1)
    ff = pad.copy()
    cv2.floodFill(ff, np.zeros((h + 4, w + 4), np.uint8), (0, 0), 2)
    return ff[1:-1, 1:-1] != 2


def _clean_mask(ink: np.ndarray, r: int = 2) -> np.ndarray:
    """The letter alone: its light body (biggest enclosed paper blob), holes
    filled, grown by its own outline width. Ink from neighbouring PAPER
    letters or paper creases that only touches the patch edges is dropped."""
    inside = _letter_mask(ink)
    body = (inside & ~ink).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(body, connectivity=4)
    if n > 1:
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        body = (lab == big).astype(np.uint8)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    grown = cv2.dilate(body, k) > 0
    grown = _letter_mask(grown)          # fill the counters (R's eye)
    return grown & (inside | ink)


def _straighten_left(patch: np.ndarray, m: np.ndarray, ink: np.ndarray):
    """PAPER's P leans into the E: its bowl takes a notch out of the E's left
    side. Rebuild that side as a straight edge: paper filled in up to the
    leftmost column the E reaches, and the outline redrawn along it."""
    body = m & ~ink
    rows = np.nonzero(body.any(axis=1))[0]
    lefts = {y: int(np.nonzero(body[y])[0][0]) for y in rows}
    edge = int(np.percentile(list(lefts.values()), 10))
    paper = np.median(patch[body], axis=0)
    outline = np.median(patch[ink & m], axis=0)
    top, bot = rows[0], rows[-1]
    for y in range(top, bot + 1):
        bx = lefts.get(y, edge)
        if bx > edge:
            # the P's old outline fades out a little past the ink threshold
            patch[y, edge:bx + 2] = paper
            m[y, edge:bx + 2] = True
        patch[y, edge - 2:edge] = outline
        m[y, edge - 2:edge] = True
    # close the top-left corner onto the top bar's outline
    corner = lefts.get(top, edge) + 3
    patch[top - 2:top, edge - 2:corner] = outline
    m[top - 2:top, edge - 2:corner] = True
    patch[bot + 1:bot + 3, edge - 2:edge + 3] = outline
    m[bot + 1:bot + 3, edge - 2:edge + 3] = True
    return patch, m


def draw_word(a: np.ndarray, src: np.ndarray, ss: int = 8):
    rgb_src = src[:, :, :3].astype(np.float32)
    lum_src = rgb_src.mean(axis=2)
    widths = {ch: COPIED[ch][2] - COPIED[ch][0] if ch in COPIED else
              int(np.ceil(max(x for x, _ in DRAWN[ch]))) + 1 for ch in COPIED.keys() | DRAWN.keys()}
    total = sum(widths[ch] + gap for ch, gap in WORD)
    x = (a.shape[1] - total) // 2 + 2
    rng = np.random.default_rng(11)
    out = a[:, :, :3].astype(np.float32)
    inside_alpha = a[:, :, 3] > 200
    for ch, gap in WORD:
        x += gap
        if ch in COPIED:
            x0, y0, x1, y1 = COPIED[ch]
            patch = rgb_src[y0:y1, x0:x1]
            ink = lum_src[y0:y1, x0:x1] < 110
            m = _clean_mask(ink)
            if ch == "E":
                patch, m = _straighten_left(patch.copy(), m, ink)
            mf = cv2.GaussianBlur(m.astype(np.float32), (3, 3), 0.6)[:, :, None]
            dy = WORD_Y - 2 + (y0 - 7)
            reg = out[dy:dy + (y1 - y0), x:x + (x1 - x0)]
            out[dy:dy + (y1 - y0), x:x + (x1 - x0)] = reg * (1 - mf) + patch * mf
        else:
            pts = DRAWN[ch]
            w = widths[ch] + 4
            h = 37 + 4
            layer = Image.new("L", (w * ss, h * ss), 0)
            # wobbly hand-drawn edges: every side cut in ~3 px steps, each nudged
            ring = pts + [pts[0]]
            jit = []
            for (ax, ay), (bx, by) in zip(ring, ring[1:]):
                n = max(1, int(np.hypot(bx - ax, by - ay) / 3))
                for k in range(n):
                    t = k / n
                    jit.append(((ax + (bx - ax) * t + 2 + rng.uniform(-0.45, 0.45)) * ss,
                                (ay + (by - ay) * t + 2 + rng.uniform(-0.45, 0.45)) * ss))
            d = ImageDraw.Draw(layer)
            for (ax, ay), (bx, by) in zip(jit, jit[1:] + jit[:1]):
                d.line([(ax, ay), (bx, by)], fill=255, width=int(rng.uniform(1.4, 1.9) * ss))
            m = np.asarray(layer).astype(np.float32) / 255.0
            m = m.reshape(h, ss, w, ss).mean(axis=(1, 3))
            m = np.clip(m * 1.25, 0, 1)[:, :, None]
            dy = WORD_Y - 2 + int(round(rng.uniform(-0.8, 0.8)))
            reg = out[dy:dy + h, x - 2:x - 2 + w]
            out[dy:dy + h, x - 2:x - 2 + w] = reg * (1 - m) + np.array(INK, np.float32) * m
        x += widths[ch]
    out = np.where(inside_alpha[:, :, None], out, a[:, :, :3].astype(np.float32))
    a[:, :, :3] = np.clip(out, 0, 255).astype(np.uint8)


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
