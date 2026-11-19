"""Survey: number every sprite found on each sheet (contact sheets for review)."""
import json
import sys
from pathlib import Path

import numpy as np

from sprites_lib import (BLUE_A, BLUE_B, BOX_LIGHT, MAGENTA, background_mask, components,
                         contact_sheet, cut, footer_row, load_rgba, sort_reading_order)

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("survey")
OUT.mkdir(parents=True, exist_ok=True)

SHEETS = {
    "shyguy_red": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Red).png",
    "shyguy_blue": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Blue).png",
    "anti_guy": "Nintendo 64 - Paper Mario - Bosses - Anti Guy.png",
    "general_guy": "Nintendo 64 - Paper Mario - Bosses - General Guy.png",
    "stilt_guy": "Nintendo 64 - Paper Mario - Bosses - Stilt Guy.png",
    "groove_guy": "Nintendo 64 - Paper Mario - Enemies - Groove Guy.png",
    "pyro_guy": "Nintendo 64 - Paper Mario - Enemies - Pyro Guy.png",
    "sky_guy": "Nintendo 64 - Paper Mario - Enemies - Sky Guy.png",
    "spear_guy": "Nintendo 64 - Paper Mario - Enemies - Spear Guy.png",
    "spy_guy": "Nintendo 64 - Paper Mario - Enemies - Spy Guy.png",
    "traffic_guy": "Nintendo 64 - Paper Mario - Non-Playable Characters - Shy Guy (Traffic Control).png",
    "rod_coin_leaf": "Nintendo 64 - Paper Mario - Miscellaneous - Star Rod, Coin, & Leaf.png",
}

report = {}
for key, fname in SHEETS.items():
    arr = load_rgba(fname)
    fy = footer_row(arr)
    arr = arr[:fy]
    bg = background_mask(arr, [MAGENTA, BLUE_A, BLUE_B, BOX_LIGHT], seed_colors=[MAGENTA, BLUE_A, BLUE_B])
    fg = ~bg
    boxes = sort_reading_order(components(fg, merge_gap=(0 if key == "groove_guy" else 1)))
    boxes = [b for b in boxes if b[4] >= 6]
    imgs = [cut(arr, bg, b) for b in boxes]
    contact_sheet(imgs, list(range(len(imgs))), scale=2, cols=12).save(OUT / f"{key}.png")
    report[key] = [b[:4] for b in boxes]
    print(key, "footer", fy, "sprites", len(boxes))
(OUT / "boxes.json").write_text(json.dumps(report))
