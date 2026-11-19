"""Shared helpers: find individual sprites on a ripped sprite sheet.

The sheets come from sprite rippers: sprites drawn on a flat magenta (or
blue) background, sometimes inside lighter boxes, with a credits footer.
We flood-fill the background from the outside, then group the remaining
pixels into connected components (one component ~ one frame).
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from paths import SRC  # noqa: E402  (original sprite sheets, see paths.py)

MAGENTA = (250, 96, 219)
BLUE_A = (89, 128, 197)
BLUE_B = (69, 100, 153)
BOX_LIGHT = (231, 231, 239)


def load_rgba(name: str) -> np.ndarray:
    im = Image.open(SRC / name).convert("RGBA")
    return np.array(im)


def footer_row(arr: np.ndarray) -> int:
    """First row of the black credits footer (rows entirely pure black)."""
    h = arr.shape[0]
    rgb = arr[:, :, :3].astype(int)
    full_black = np.all(rgb.reshape(h, -1) == 0, axis=1)
    # walk up from bottom while rows are mostly black or text
    y = h
    for row in range(h - 1, -1, -1):
        blackish = np.mean(np.all(rgb[row] < 40, axis=1) | np.all(rgb[row] > 200, axis=1))
        if full_black[row] or (blackish > 0.97 and np.mean(np.all(rgb[row] == 0, axis=1)) > 0.5):
            y = row
        else:
            break
    return y


def background_mask(arr: np.ndarray, bg_colors, seed_colors=None) -> np.ndarray:
    """True where pixel is background reachable from a seed bg pixel."""
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    is_bgcol = alpha == 0
    for c in bg_colors:
        is_bgcol |= np.all(rgb == np.array(c, dtype=np.uint8), axis=2)
    seeds = np.zeros((h, w), bool)
    seed_colors = seed_colors or bg_colors
    for c in seed_colors:
        seeds |= np.all(rgb == np.array(c, dtype=np.uint8), axis=2)
    seeds |= alpha == 0
    seeds[0, :] |= is_bgcol[0, :]
    seeds[-1, :] |= is_bgcol[-1, :]
    seeds[:, 0] |= is_bgcol[:, 0]
    seeds[:, -1] |= is_bgcol[:, -1]
    bg = np.zeros((h, w), bool)
    q = deque()
    ys, xs = np.nonzero(seeds & is_bgcol)
    for y, x in zip(ys.tolist(), xs.tolist()):
        bg[y, x] = True
        q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and is_bgcol[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    return bg


def components(fg: np.ndarray, merge_gap: int = 1):
    """8-connected components; boxes closer than merge_gap px are merged."""
    h, w = fg.shape
    lab = np.zeros((h, w), np.int32)
    boxes = []
    cur = 0
    for y in range(h):
        for x in range(w):
            if fg[y, x] and lab[y, x] == 0:
                cur += 1
                q = deque([(y, x)])
                lab[y, x] = cur
                x0 = x1 = x
                y0 = y1 = y
                n = 0
                while q:
                    cy, cx = q.popleft()
                    n += 1
                    x0, x1 = min(x0, cx), max(x1, cx)
                    y0, y1 = min(y0, cy), max(y1, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = cur
                                q.append((ny, nx))
                boxes.append([x0, y0, x1 + 1, y1 + 1, n])
    # merge close boxes
    changed = True
    while changed:
        changed = False
        out = []
        while boxes:
            b = boxes.pop()
            merged = True
            while merged:
                merged = False
                for o in boxes:
                    if (b[0] - merge_gap <= o[2] and o[0] - merge_gap <= b[2]
                            and b[1] - merge_gap <= o[3] and o[1] - merge_gap <= b[3]):
                        b = [min(b[0], o[0]), min(b[1], o[1]), max(b[2], o[2]), max(b[3], o[3]), b[4] + o[4]]
                        boxes.remove(o)
                        merged = changed = True
                        break
            out.append(b)
        boxes = out
    boxes.sort(key=lambda b: (b[1] // 8, b[0]))
    # stable row grouping: sort by row band then x
    return boxes


def sort_reading_order(boxes, band=None):
    """Group boxes into rows (by vertical overlap) then sort by x."""
    boxes = sorted(boxes, key=lambda b: b[1])
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        for r in rows:
            if r["y0"] - 2 <= cy <= r["y1"] + 2:
                r["items"].append(b)
                r["y0"] = min(r["y0"], b[1])
                r["y1"] = max(r["y1"], b[3])
                break
        else:
            rows.append({"y0": b[1], "y1": b[3], "items": [b]})
    rows.sort(key=lambda r: r["y0"])
    out = []
    for r in rows:
        out.extend(sorted(r["items"], key=lambda b: b[0]))
    return out


def cut(arr: np.ndarray, bg: np.ndarray, box) -> Image.Image:
    x0, y0, x1, y1 = box[:4]
    sub = arr[y0:y1, x0:x1].copy()
    m = bg[y0:y1, x0:x1]
    sub[m] = 0
    return Image.fromarray(sub, "RGBA")


def contact_sheet(images, labels, scale=3, cols=10, bgcol=(60, 60, 70, 255)) -> Image.Image:
    cw = max(i.width for i in images) * scale + 8
    ch = max(i.height for i in images) * scale + 22
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols, ch * rows), bgcol)
    d = ImageDraw.Draw(sheet)
    for k, (im, lab) in enumerate(zip(images, labels)):
        cx, cy = (k % cols) * cw, (k // cols) * ch
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        d.rectangle([cx + 2, cy + 16, cx + cw - 3, cy + ch - 3], fill=(90, 90, 105, 255))
        sheet.alpha_composite(big, (cx + 4, cy + 18))
        d.text((cx + 4, cy + 2), str(lab), fill=(255, 255, 0, 255))
    return sheet
