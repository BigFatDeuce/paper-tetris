"""Bowser for the Bowser's Castle stage: the idle animation (PM_Bowser_idle.gif
in the source rips) packed into one frame sheet + timing, for
game/src/stage/bowser.gd.

    python build_bowser.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

from paths import SRC

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "sprites" / "bowser"
GIF = SRC / "PM_Bowser_idle.gif"
COLS = 12


def main():
    im = Image.open(GIF)
    frames, durs = [], []
    for i, f in enumerate(ImageSequence.Iterator(im)):
        rgba = f.convert("RGBA")
        d = int(f.info.get("duration", 30))
        # merge runs of identical frames into one longer frame
        if frames and np.array_equal(np.asarray(frames[-1]), np.asarray(rgba)):
            durs[-1] += d
        else:
            frames.append(rgba)
            durs.append(d)
    w, h = frames[0].size
    rows = (len(frames) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (w * COLS, h * rows), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sheet.paste(f, ((k % COLS) * w, (k // COLS) * h))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "bowser_idle.png")
    meta = {"cell": [w, h], "cols": COLS, "durations_ms": durs}
    (OUT / "bowser_idle.json").write_text(json.dumps(meta), encoding="utf-8")
    print(f"bowser_idle.png: {len(frames)} frames ({sum(durs)} ms), sheet {sheet.size}")


if __name__ == "__main__":
    main()
