"""Build the Paper Mario dialogue font as BMFont (.fnt + .png) files for Godot.

Glyphs are cut from the ripped font sheet (first, grey block), their grey
fill is normalised to white so the font can be tinted with font_color while
keeping its dark outline. Integer-scaled variants (x2, x3, x4) are written
so the font stays pixel-crisp at 1080p without runtime filtering.
"""
from pathlib import Path

import numpy as np
from PIL import Image

from sprites_lib import SRC, components

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "fonts"

ROWS = [
    ((7, 21), '♪!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQR'),
    ((24, 40), "STUVWXYZ[¥]^_`abcdefghijklmnopqrstuvwxyz{|}~°ÀÁÂÄÇÈÉ"),
    ((45, 61), "ÊËÌÍÎÏÑÒÓÔÖÙÚÛÜßàáâäçèéêëìíîïñòóôöùúûü¡¿ª♡☆↑↓←→○×"),
]
TRACKING = -1        # outlines overlap by one pixel, like the original text boxes
SPACE_ADV = 5


def glyph_boxes(op_row):
    comps = components(op_row, merge_gap=0)
    comps.sort(key=lambda b: b[0])
    # group components that overlap (or nearly touch) horizontally
    groups = []
    for b in comps:
        if groups and b[0] <= groups[-1][2] + 0:
            g = groups[-1]
            groups[-1] = [min(g[0], b[0]), min(g[1], b[1]), max(g[2], b[2]), max(g[3], b[3])]
        else:
            groups.append(list(b[:4]))
    return groups


def main():
    sheet = Image.open(SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Fonts.png").convert("RGBA")
    a = np.array(sheet).astype(np.float32)
    # normalise grey fill (214) to white, keep alpha
    a[:, :, :3] = np.clip(a[:, :, :3] * (255.0 / 214.0), 0, 255)
    a = a.astype(np.uint8)
    op = a[:, :, 3] > 0
    glyphs = {}
    for (y0, y1), chars in ROWS:
        y0p, y1p = y0 - 2, y1 + 2
        boxes = glyph_boxes(op[y0p:y1p])
        # glue '"' style multi-part glyphs: if more boxes than chars, merge
        # the closest pairs until counts match
        while len(boxes) > len(chars):
            gaps = [(boxes[i + 1][0] - boxes[i][2], i) for i in range(len(boxes) - 1)]
            _, i = min(gaps)
            b, c = boxes[i], boxes[i + 1]
            boxes[i:i + 2] = [[min(b[0], c[0]), min(b[1], c[1]), max(b[2], c[2]), max(b[3], c[3])]]
        if len(boxes) != len(chars):
            raise SystemExit(f"row {y0}: {len(boxes)} glyphs for {len(chars)} chars")
        # baseline = most common bottom
        bottoms = [b[3] for b in boxes]
        base = max(set(bottoms), key=bottoms.count)
        for ch, b in zip(chars, boxes):
            img = Image.fromarray(a[y0p:y1p][b[1]:b[3], b[0]:b[2]], "RGBA")
            glyphs[ch] = (img, b[1] - base)  # top relative to baseline (negative)
    # metrics
    ascent = -min(t for _, t in glyphs.values())
    descent = max(img.height + t for img, t in glyphs.values())
    line_h = ascent + descent + 2
    OUT.mkdir(parents=True, exist_ok=True)
    for scale in (1, 2, 3, 4):
        write_font(glyphs, ascent, line_h, scale)
    # "ink" variant: fill only (no dark outline) for dark text on paper,
    # like the dialogue boxes of the original game
    ink = {}
    for ch, (img, top) in glyphs.items():
        arr = np.array(img).astype(np.float32)
        # outline (49) -> transparent, fill (214, normalised to 255) -> opaque,
        # the in-between greys become pixel anti-aliasing
        v = arr[:, :, :3].mean(axis=2) * (214.0 / 255.0)
        alpha = np.clip((v - 49.0) / (214.0 - 49.0), 0, 1) * (arr[:, :, 3] / 255.0)
        arr[:, :, :3] = 255
        arr[:, :, 3] = alpha * 255
        arr = arr.astype(np.uint8)
        ink[ch] = (Image.fromarray(arr, "RGBA"), top)
    for scale in (1, 2, 3, 4):
        write_font(ink, ascent, line_h, scale, "paper_ink")
    print("glyphs:", len(glyphs), "ascent", ascent, "descent", descent)


def write_font(glyphs, ascent, line_h, s, prefix="paper_font"):
    name = f"{prefix}_x{s}"
    pad = 1 * s
    cols = 16
    cw = max(g.width for g, _ in glyphs.values()) * s + pad * 2
    chh = max(g.height for g, _ in glyphs.values()) * s + pad * 2
    items = list(glyphs.items())
    rows = (len(items) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * cw, rows * chh), (0, 0, 0, 0))
    lines = [f'info face="PaperFont" size={line_h * s} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
             f'padding=0,0,0,0 spacing=0,0',
             f'common lineHeight={line_h * s} base={(ascent + 1) * s} scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0',
             f'page id=0 file="{name}.png"',
             f'chars count={len(items) + 1}']
    for k, (ch, (img, top)) in enumerate(items):
        x = (k % cols) * cw + pad
        y = (k // cols) * chh + pad
        big = img.resize((img.width * s, img.height * s), Image.NEAREST)
        atlas.alpha_composite(big, (x, y))
        yoff = (ascent + 1 + top) * s
        adv = (img.width + TRACKING) * s
        lines.append(f"char id={ord(ch)} x={x} y={y} width={big.width} height={big.height} "
                     f"xoffset=0 yoffset={yoff} xadvance={adv} page=0 chnl=15")
    lines.append(f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={SPACE_ADV * s} page=0 chnl=15")
    atlas.save(OUT / f"{name}.png")
    (OUT / f"{name}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
