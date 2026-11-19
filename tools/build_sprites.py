"""Build character atlases + Godot SpriteFrames (.tres) and UI sprites.

Frames are cut from the ripped sheets (indices = reading order found by
survey_sheets.py), aligned on a common baseline (feet) and horizontally on
the body silhouette, then packed into one atlas per character.
Sprites are never resampled: pixels stay exactly as ripped.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from sprites_lib import (BLUE_A, BLUE_B, BOX_LIGHT, MAGENTA, SRC, background_mask, components, cut,
                         footer_row, load_rgba, sort_reading_order)

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "game" / "assets" / "sprites" / "characters"
UI_DIR = ROOT / "game" / "assets" / "sprites" / "ui"

SHEETS = {
    "shyguy_red": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Red).png",
    "shyguy_blue": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Blue).png",
    "shyguy_green": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Green).png",
    "shyguy_pink": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Pink).png",
    "shyguy_yellow": "Nintendo 64 - Paper Mario - Enemies - Shy Guy (Yellow).png",
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

# Standard Shy Guy layout (blue/green/pink/yellow/anti guy sheets).
STD = {
    "idle": ([0, 1, 2, 3], 4, True),
    "walk": ([0, 1, 2, 3], 8, True),
    "run": ([4, 5, 6, 7], 13, True),
    "crouch": ([21, 22], 6, False),
    "jump": ([11], 1, False),
    "fall": ([8], 1, False),
    "land": ([20], 1, False),
    "cheer": ([15, 16], 6, True),
    "front": ([31], 1, False),
    "look_up": ([17], 1, False),
    "squat": ([18, 19], 3, True),
    "tumble": ([29, 30, 25, 9], 10, True),
    "dizzy": ([25, 31], 3, True),
    "flail": ([8, 9], 8, True),
    "knocked": ([12, 13, 14], 8, False),
    "lie": ([23, 24], 2, True),
    "sleep": ([26], 1, False),
    "back": ([27, 28], 4, True),
    "spin": ([31, 27, 28, 0], 12, True),
    "burnt": ([32, 33], 4, True),
    "smoke": ([34, 35, 36, 37, 38, 39, 40, 41, 42, 43], 14, False),
    "sling": ([44, 45, 46, 47, 48, 49, 51], 10, False),
}
# blue index -> red index (the red sheet has a few extra sprites)
RED_MAP = {i: i for i in range(15)}
RED_MAP.update({15: 16, 16: 17, 17: 18, 18: 19, 19: 20, 20: 21, 21: 22, 22: 23, 23: 24, 24: 25, 25: 26,
                26: 27, 27: 28, 28: 29, 29: 32, 30: 33, 31: 34, 32: 35, 33: 36})
RED_MAP.update({34 + k: 38 + k for k in range(10)})
RED_MAP.update({44 + k: 49 + k for k in range(6)})
RED_MAP.update({50: 55, 51: 56})


def remap(anims, mapping):
    return {k: ([mapping[i] for i in fr], fps, loop) for k, (fr, fps, loop) in anims.items()}


CHARACTERS = {
    "shyguy_red": {"anims": remap(STD, RED_MAP), "ref": 0},
    "shyguy_blue": {"anims": STD, "ref": 0},
    "shyguy_green": {"anims": STD, "ref": 0},
    "shyguy_pink": {"anims": STD, "ref": 0},
    "shyguy_yellow": {"anims": STD, "ref": 0},
    "anti_guy": {"anims": STD, "ref": 0},
    "groove_guy": {"anims": {
        "idle": ([0, 1], 3, True),
        "walk": ([0, 1, 2, 3], 8, True),
        "dance": ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 12, True),
        "dance2": ([16, 17, 18, 19, 20, 21, 22, 23, 24], 10, True),
        "lie": ([10], 1, False),
        "flail": ([11, 12], 8, True),
        "burnt": ([13, 14], 4, True),
        "land": ([25], 1, False),
    }, "ref": 0},
    "pyro_guy": {"anims": {
        "idle": ([0, 1, 2, 3], 9, True),
        "walk": ([12, 13, 14, 15, 16], 10, True),
        "jump": ([6, 7], 8, True),
        "lie": ([9, 10, 11], 6, True),
        "flare": ([4, 5], 8, True),
        "faded": ([28, 29, 30, 31], 9, True),
    }, "ref": 0},
    "sky_guy": {"anims": {
        "float": ([15, 16, 17], 4, True),
        "aim": ([0, 1, 2, 3, 4, 5], 8, True),
        "hold": ([7], 1, False),
        "fall": ([19, 20, 21], 10, True),
        "burnt": ([23, 24, 25], 6, True),
    }, "ref": 15, "parts": {"balloon_red": 32, "balloon_orange": 39, "balloon_blue": 47,
                            "pop_red": 33, "pop_orange": 40, "pop_blue": 48, "string": 26}},
    "spear_guy": {"anims": {
        "idle": ([0, 1, 2, 3], 5, True),
        "walk": ([4, 5, 6, 7, 8], 9, True),
        "hop": ([9, 10, 11], 8, True),
        "dance": ([27, 28, 29, 30, 32, 33], 9, True),
        "burnt": ([15, 16, 17], 4, True),
    }, "ref": 0, "parts": {"spear": 42}},
    "spy_guy": {"anims": {
        "idle": ([0], 1, False),
        "walk": ([14, 15, 16, 17], 9, True),
        "sling": ([1, 2, 3, 4], 8, True),
        "sit": ([18, 19, 20, 21], 6, True),
        "hammer": ([8, 9, 10, 11, 12, 13], 9, True),
    }, "ref": 0, "parts": {"mug": 24}},
    "traffic_guy": {"anims": {
        "idle": ([0, 1], 3, True),
        "signal": ([8, 9, 10, 11], 6, True),
        "signal2": ([20, 21, 22, 23], 6, True),
        "wave": ([24, 25, 26], 6, True),
        "lie": ([2, 3], 3, True),
        "back": ([6, 7], 4, True),
        "jump": ([12, 13, 14], 8, True),
    }, "ref": 0},
    "stilt_guy": {"anims": {
        "idle": ([2, 5], 3, True),
        "wobble": ([14, 15, 16, 17], 7, True),
        "flail": ([9, 10], 8, True),
    }, "ref": 2, "parts": {"stilt": 0}},
    "general_guy": {"anims": {
        "idle": ([0, 6], 3, True),
        "walk": ([17, 18, 19], 7, True),
        "salute": ([9, 10, 11], 6, True),
        "cheer": ([13, 14], 6, True),
        "lie": ([8], 1, False),
    }, "ref": 0, "parts": {"bomb": 31}},
}


def sheet_frames(key):
    arr = load_rgba(SHEETS[key])
    arr = arr[:footer_row(arr)]
    bg = background_mask(arr, [MAGENTA, BLUE_A, BLUE_B, BOX_LIGHT], seed_colors=[MAGENTA, BLUE_A, BLUE_B])
    gap = 0 if key == "groove_guy" else 1
    boxes = sort_reading_order([b for b in components(~bg, merge_gap=gap) if b[4] >= 6])
    return [cut(arr, bg, b) for b in boxes]


def best_dx(img: Image.Image, ref: Image.Image, search=12) -> int:
    """Horizontal shift (bottom aligned, centers) maximising silhouette overlap."""
    a = np.array(img)[:, :, 3] > 0
    r = np.array(ref)[:, :, 3] > 0
    H = max(a.shape[0], r.shape[0])
    W = max(a.shape[1], r.shape[1]) + 2 * search + 4
    def place(m, dx):
        c = np.zeros((H, W), bool)
        x0 = (W - m.shape[1]) // 2 + dx
        c[H - m.shape[0]:, x0:x0 + m.shape[1]] = m
        return c
    rc = place(r, 0)
    best, bdx = -1.0, 0
    for dx in range(-search, search + 1):
        c = place(a, dx)
        inter = np.logical_and(c, rc).sum()
        union = np.logical_or(c, rc).sum()
        iou = inter / max(union, 1)
        if iou > best + 1e-9 or (abs(iou - best) < 1e-9 and abs(dx) < abs(bdx)):
            best, bdx = iou, dx
    return bdx


def tres_spriteframes(atlas_res: str, frames_rects, anims, cell):
    """frames_rects: {frame_index: (x,y,w,h)}; anims: name -> (list, fps, loop)."""
    lines = []
    used = sorted({i for fr, _, _ in anims.values() for i in fr})
    sub = {}
    n_res = len(used)
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={n_res + 2} format=3]\n')
    lines.append(f'[ext_resource type="Texture2D" path="{atlas_res}" id="1_atlas"]\n')
    for k, i in enumerate(used):
        x, y, w, h = frames_rects[i]
        sid = f"AtlasTexture_f{i}"
        sub[i] = sid
        lines.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1_atlas")\n'
                     f'region = Rect2({x}, {y}, {w}, {h})\n')
    lines.append("[resource]\nanimations = [")
    blocks = []
    for name, (fr, fps, loop) in anims.items():
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sub[i] for i in fr)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, "true" if loop else "false", name, float(fps)))
    lines.append(", ".join(blocks) + "]\n")
    return "\n".join(lines)


def build_character(key, spec):
    frames = sheet_frames(key)
    anims = spec["anims"]
    used = sorted({i for fr, _, _ in anims.values() for i in fr})
    ref = frames[spec["ref"]]
    offs = {}
    for i in used:
        offs[i] = best_dx(frames[i], ref)
    # common cell: bottom aligned, centred + dx
    pad = 2
    max_h = max(frames[i].height for i in used)
    left = min(-(frames[i].width // 2) + offs[i] for i in used)
    right = max(frames[i].width - frames[i].width // 2 + offs[i] for i in used)
    cw = right - left + 2 * pad
    ch = max_h + 2 * pad
    cols = min(len(used), 8)
    rows = (len(used) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    rects = {}
    for k, i in enumerate(used):
        cx, cy = (k % cols) * cw, (k // cols) * ch
        im = frames[i]
        x = cx + pad + (-left) - im.width // 2 + offs[i]
        y = cy + ch - pad - im.height
        atlas.alpha_composite(im, (x, y))
        rects[i] = (cx, cy, cw, ch)
    CHAR_DIR.mkdir(parents=True, exist_ok=True)
    atlas.save(CHAR_DIR / f"{key}.png")
    # foot point inside the cell: (pad - left, ch - pad)
    meta = {"cell": [cw, ch], "foot": [pad - left, ch - pad], "anims": list(anims.keys())}
    tres = tres_spriteframes(f"res://assets/sprites/characters/{key}.png", rects, anims, (cw, ch))
    (CHAR_DIR / f"{key}_frames.tres").write_text(tres, encoding="utf-8")
    # loose parts (balloons, spear, stilts...)
    for pname, idx in spec.get("parts", {}).items():
        frames[idx].save(CHAR_DIR / f"{key}_{pname}.png")
    return meta


def trim(im: Image.Image) -> Image.Image:
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def despeckle(im: Image.Image, min_px: int = 4) -> Image.Image:
    """Drop tiny isolated pixel groups left over from neighbouring sprites."""
    a = np.array(im)
    fg = a[:, :, 3] > 0
    for b in components(fg, merge_gap=0):
        if b[4] < min_px:
            x0, y0, x1, y1 = b[:4]
            a[y0:y1, x0:x1, 3] = np.where(fg[y0:y1, x0:x1], 0, a[y0:y1, x0:x1, 3])
    return trim(Image.fromarray(a, "RGBA"))


def build_ui():
    UI_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Battle Extras & HUD.png").convert("RGBA")
    hud = json.loads((Path(__file__).parent / "hud_boxes.json").read_text())

    def box(region, i):
        x0, y0, x1, y1 = hud[region][i]
        return sheet.crop((x0, y0, x1, y1))

    def rough(x0, y0, x1, y1):
        return despeckle(trim(sheet.crop((x0, y0, x1, y1))))

    # spinning star point (8 frames) -> strip
    stars = [box("menu_hud", i) for i in range(12, 20)]
    strip(stars, UI_DIR / "star_spin.png")
    # glove cursor (white glove pointing right) — manual crop, auto-trim
    rough(118, 220, 140, 238).save(UI_DIR / "glove.png")
    box("menu_hud", 40).save(UI_DIR / "heart.png")
    box("menu_hud", 41).save(UI_DIR / "flower.png")
    # big orange numbers 1..7 and cream numbers 1..4
    for n, i in zip(range(1, 8), [6, 7, 8, 9, 20, 21, 22]):
        box("action", i).save(UI_DIR / f"num_orange_{n}.png")
    for n, i in zip(range(1, 5), [49, 50, 52, 54]):
        box("action", i).save(UI_DIR / f"num_cream_{n}.png")
    box("action", 17).save(UI_DIR / "cloud.png")
    box("action", 18).save(UI_DIR / "target.png")
    box("action", 19).save(UI_DIR / "block_blue.png")
    box("action", 15).save(UI_DIR / "star_red.png")
    box("action", 16).save(UI_DIR / "star_blue.png")
    # words (manual rects, auto-trimmed)
    words = {"nice": (672, 174, 733, 199), "good": (736, 174, 796, 199), "super": (798, 174, 866, 199),
             "miss": (867, 174, 930, 199), "lucky": (931, 174, 1000, 199)}
    for name, r in words.items():
        rough(*r).save(UI_DIR / f"word_{name}.png")
    rough(938, 125, 1000, 165).save(UI_DIR / "burst_100.png")
    # item icons
    items = {"mushroom": 157, "super_shroom": 158, "stopwatch": 198, "pow": 197, "fire_flower": 38,
             "star": 39, "shooting_star": 187, "snowman": 184, "thunder": 185, "egg": 165, "lemon": 175,
             "apple": 179, "cake": 232, "honey": 182, "coconut": 166, "melon": 167, "sleepy": 196,
             "dizzy": 199, "maple": 177, "question": 124, "volt": 186, "lollipop": 226, "spaghetti": 212}
    for name, i in items.items():
        box("items", i).save(UI_DIR / f"item_{name}.png")
    # coins: rotating coin from the coin HUD sheet (top row)
    coin_sheet = Image.open(SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Coin (HUD).png").convert("RGBA")
    a = np.array(coin_sheet)
    gold = (a[:, :, 3] > 0) & (a[:, :, :3].astype(int).sum(axis=2) > 120)
    gold[30:, :] = False
    bx = sort_reading_order([b for b in components(gold, merge_gap=0) if b[4] > 20 and b[0] < 250])
    coins = [trim(coin_sheet.crop(tuple(b[:4]))) for b in bx][:9]
    strip(coins, UI_DIR / "coin_spin.png", cell=(max(c.width for c in coins), max(c.height for c in coins)))
    # misc from rod sheet
    rod = sheet_frames("rod_coin_leaf")
    rod[0].save(UI_DIR / "star_rod.png")
    rod[12].save(UI_DIR / "leaf.png")
    print("ui sprites ok, coins:", len(coins))


def strip(frames, path, cell=None):
    cw = cell[0] if cell else max(f.width for f in frames)
    ch = cell[1] if cell else max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        out.alpha_composite(f, (k * cw + (cw - f.width) // 2, (ch - f.height) // 2))
    out.save(path)
    (path.with_suffix(".json")).write_text(json.dumps({"frames": len(frames), "w": cw, "h": ch}))


def main():
    metas = {}
    for key, spec in CHARACTERS.items():
        metas[key] = build_character(key, spec)
        print(key, metas[key]["cell"])
    (ROOT / "game" / "data").mkdir(parents=True, exist_ok=True)
    (ROOT / "game" / "data" / "characters_meta.json").write_text(json.dumps(metas, indent=1))
    build_ui()


if __name__ == "__main__":
    main()
