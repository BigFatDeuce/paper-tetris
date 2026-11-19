"""Builds the stage dioramas from the original Paper Mario 64 material.

Each stage = the painted battle background (from tools/pm_render/src/
battle_bgs.png, upscaled) + layers rendered in 3D by tools/pm_render
(the real battle stage / field models and N64 textures, rendered with the
game's unshaded vertex-colour look) split into a back layer (behind the
Shy Guys) and a front layer (over them).

    python build_pm_stages.py [stage ...] [--preview]
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
RENDER = TOOLS / "pm_render"
GODOT = TOOLS / "bin" / "godot" / "Godot_v4.7.2-stable_win64_console.exe"
OUT = ROOT / "game" / "assets" / "stages"
TMP = RENDER / "out"
W, H = 1920, 1080
SS = 2  # supersampling of the 3D renders

# cells of the battle background sheet (x0, y0, x1, y1), 1 px inset
BG_COLS = [(1, 294), (298, 592), (596, 890), (894, 1188)]
BG_ROWS = [(1, 198), (202, 400), (404, 602), (606, 804), (808, 1006)]
BG = {
    "jungle_a": (0, 0), "dunes_a": (0, 1), "dark_red": (0, 2), "flowers_sun": (0, 3),
    "snow_peaks": (1, 0), "crystal": (1, 1), "pleasant": (1, 2), "flowers_storm": (1, 3),
    "toybox": (2, 1), "jungle_b": (2, 2),
    "cloud_sweets": (3, 0), "sandstorm": (3, 1), "rugged": (3, 2),
    "dunes_b": (4, 0), "goomba": (4, 1), "stars": (4, 2),
}

from pm_stage_defs import stage_defs

STAGES = {}


def bg_image(name: str, y_off: int, flip=False) -> Image.Image:
    sheet = Image.open(RENDER / "src" / "battle_bgs.png").convert("RGB")
    r, c = BG[name]
    x0, x1 = BG_COLS[c]
    y0, y1 = BG_ROWS[r]
    im = sheet.crop((x0, y0, x1 + 1, y1 + 1))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    k = W / im.width
    big = im.resize((W, round(im.height * k)), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2.0, percent=55, threshold=2))
    out = Image.new("RGB", (W, H))
    out.paste(big, (0, y_off))
    if y_off > 0:  # stretch the top row up if the picture was pushed down
        top = big.crop((0, 0, W, 1)).resize((W, y_off))
        out.paste(top, (0, 0))
    if y_off + big.height < H:
        bot = big.crop((0, big.height - 1, W, big.height)).resize((W, H - y_off - big.height))
        out.paste(bot, (0, y_off + big.height))
    return out


def render(stage: str, cfg: dict, passes: list) -> dict:
    TMP.mkdir(exist_ok=True)
    spec = {
        "size": [W * SS, H * SS],
        "camera": cfg["camera"],
        "items": cfg["items"],
        "passes": [{"name": p, "out": str(TMP / f"{stage}_{p}.png")} for p in passes],
    }
    spec_path = TMP / f"{stage}.json"
    spec_path.write_text(json.dumps(spec, indent=1))
    subprocess.run([str(GODOT), "--path", str(RENDER), "--resolution", "640x360",
                    "--", f"spec={spec_path}"], check=True, capture_output=True)
    res = {}
    for p in passes:
        raw = TMP / f"{stage}_{p}.png"
        res[p] = downsample(Image.open(raw).convert("RGBA"))
        raw.unlink()  # 4K intermediates are only needed for the downsample
    return res


def downsample(im: Image.Image) -> Image.Image:
    # premultiplied resize so the transparent edges do not go dark
    a = np.asarray(im).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    pm = Image.fromarray((a * 255).astype(np.uint8), "RGBA")
    small = np.asarray(pm.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255.0
    al = np.clip(small[..., 3:4], 1e-4, 1)
    rgb = np.where(small[..., 3:4] > 0.003, small[..., :3] / al, 0)
    out = np.concatenate([np.clip(rgb, 0, 1), np.clip(small[..., 3:4], 0, 1)], axis=2)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def crop_layer(im: Image.Image):
    bbox = im.getbbox()
    if bbox is None:
        return None, (0, 0)
    return im.crop(bbox), (bbox[0], bbox[1])


def build(stage: str, preview_dir: Path | None):
    cfg = STAGES[stage]
    folder = OUT / stage
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    layers = []
    sky = bg_image(cfg["bg"], cfg.get("bg_y", 0), cfg.get("bg_flip", False))
    sky.save(folder / "sky.png", optimize=True)
    layers.append({"file": "sky.png", "x": 0, "y": 0, "base": H, "sway": 0.0, "depth": 0.0, "front": False})
    passes = cfg.get("passes", ["back", "front"])
    imgs = render(stage, cfg, passes)
    for p in passes:
        im, (x, y) = crop_layer(imgs[p])
        if im is None:
            continue
        name = f"{p}.png"
        im.save(folder / name, optimize=True)
        meta = cfg.get("layer_meta", {}).get(p, {})
        layers.append({
            "file": name, "x": x, "y": y, "base": y + im.height,
            "sway": meta.get("sway", 0.0), "depth": meta.get("depth", 0.5),
            "front": p == "front" or meta.get("front", False),
        })
    (folder / "layers.json").write_text(json.dumps({"layers": layers, "ground": cfg.get("ambient_ground", 935)}, indent=1))
    print(stage, [l["file"] for l in layers])
    if preview_dir:
        preview(stage, preview_dir)


def preview(stage: str, out_dir: Path):
    sys.argv = [sys.argv[0], str(out_dir), stage]
    import importlib
    import preview_stage
    importlib.reload(preview_stage)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pv = None
    for a in sys.argv[1:]:
        if a.startswith("--preview="):
            pv = Path(a.split("=", 1)[1])
    STAGES.update(stage_defs())
    # new or recoloured textures must be imported before rendering
    subprocess.run([str(GODOT), "--headless", "--path", str(RENDER), "--import"], capture_output=True)
    for s in args or list(STAGES):
        build(s, pv)
