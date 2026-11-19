"""Composite a stage's layers into one preview image (with the board area)."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
out_dir = Path(sys.argv[1])
names = sys.argv[2:]
tiles = []
for n in names:
    folder = ROOT / "game" / "assets" / "stages" / n
    meta = json.loads((folder / "layers.json").read_text())
    canvas = Image.new("RGBA", (1920, 1080), (0, 0, 0, 255))
    for l in meta["layers"]:
        im = Image.open(folder / l["file"]).convert("RGBA")
        canvas.alpha_composite(im, (l["x"], l["y"]))
    d = ImageDraw.Draw(canvas)
    d.rectangle([718, 124, 1202, 1046], outline=(255, 255, 255, 200), width=3)
    d.rectangle([426, 152, 676, 820], outline=(255, 255, 255, 120), width=2)
    d.rectangle([1244, 152, 1494, 612], outline=(255, 255, 255, 120), width=2)
    canvas.convert("RGB").save(out_dir / f"stage_{n}.png")
    tiles.append(canvas.resize((960, 540), Image.LANCZOS))
if len(tiles) > 1:
    cols = 2
    rows = (len(tiles) + 1) // 2
    grid = Image.new("RGB", (960 * cols, 540 * rows))
    for i, t in enumerate(tiles):
        grid.paste(t.convert("RGB"), ((i % cols) * 960, (i // cols) * 540))
    grid.save(out_dir / "stages_grid.png")
