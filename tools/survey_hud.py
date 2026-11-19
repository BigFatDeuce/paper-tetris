"""Survey of the HUD / battle extras sheet: numbered overlay per region."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from sprites_lib import SRC, components, sort_reading_order

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

REGIONS = {
    "menu_hud": (8, 170, 158, 290),
    "damage": (210, 30, 368, 246),
    "status": (378, 30, 640, 222),
    "action": (668, 30, 1004, 242),
    "items": (8, 300, 1004, 612),
}

im = Image.open(SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Battle Extras & HUD.png").convert("RGBA")
arr = np.array(im)
report = {}
for key, (x0, y0, x1, y1) in REGIONS.items():
    sub = arr[y0:y1, x0:x1]
    a = sub[:, :, 3] > 0
    # remove the white/black frame lines of the section boxes: ignore thin long runs
    fg = a.copy()
    # erase long straight runs (section frame lines)
    for axis in (0, 1):
        m = fg if axis == 0 else fg.T
        for i in range(m.shape[0]):
            row = m[i]
            j = 0
            n = row.shape[0]
            while j < n:
                if row[j]:
                    k = j
                    while k < n and row[k]:
                        k += 1
                    if k - j >= 45:
                        row[j:k] = False
                    j = k
                else:
                    j += 1
    boxes = components(fg, merge_gap=0)
    boxes = [b for b in boxes if b[4] >= 4 and (b[2] - b[0]) < 120 and (b[3] - b[1]) < 120]
    boxes = sort_reading_order(boxes)
    scale = 3 if key != "items" else 2
    big = Image.fromarray(sub, "RGBA").resize(((x1 - x0) * scale, (y1 - y0) * scale), Image.NEAREST)
    canvas = Image.new("RGBA", big.size, (90, 90, 110, 255))
    canvas.alpha_composite(big)
    d = ImageDraw.Draw(canvas)
    for i, b in enumerate(boxes):
        d.rectangle([b[0] * scale, b[1] * scale, b[2] * scale - 1, b[3] * scale - 1], outline=(0, 255, 0, 255))
        d.text((b[0] * scale + 1, b[1] * scale - 1), str(i), fill=(255, 255, 0, 255))
    canvas.save(OUT / f"hud_{key}.png")
    report[key] = [[b[0] + x0, b[1] + y0, b[2] + x0, b[3] + y0] for b in boxes]
    print(key, len(boxes))
(OUT / "hud_boxes.json").write_text(json.dumps(report))

# Coin HUD sheet
im2 = Image.open(SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Coin (HUD).png").convert("RGBA")
a2 = np.array(im2)
fg = a2[:, :, 3] > 0
boxes = sort_reading_order([b for b in components(fg, merge_gap=0) if b[4] >= 4])
scale = 3
big = im2.resize((im2.width * scale, im2.height * scale), Image.NEAREST)
canvas = Image.new("RGBA", big.size, (90, 90, 110, 255))
canvas.alpha_composite(big)
d = ImageDraw.Draw(canvas)
for i, b in enumerate(boxes):
    d.rectangle([b[0] * scale, b[1] * scale, b[2] * scale - 1, b[3] * scale - 1], outline=(0, 255, 0, 255))
    d.text((b[0] * scale + 1, b[1] * scale - 1), str(i), fill=(255, 0, 0, 255))
canvas.save(OUT / "hud_coin.png")
(OUT / "coin_boxes.json").write_text(json.dumps([b[:4] for b in boxes]))
print("coin", len(boxes))
