"""Stage compositions for build_pm_stages.py.

Every diorama follows the Paper Mario 64 battle stage recipe: the painted
background, a textured floor seen in perspective and flat cut-outs / boxes
dressed with original N64 textures (recoloured when a stage needs it).
World units are those of the Pleasant Path battle stage model; the Shy
Guys walk around z 0.23..0.31, so props stay behind z 0.2 (back layer) or
sit at the very front corners (front layer).
"""
from pathlib import Path

import numpy as np
from PIL import Image

RENDER = Path(__file__).resolve().parent / "pm_render"
TEX = RENDER / "tex"

PP = "res://models/pleasant/Battle-Pleasant_Path_1.obj"
PPT = "res://models/pleasant/Textures/"

# Pleasant Path battle stage texture roles
PP_FLOOR = "61477051_c.png"
PP_WOOD = "33D454B4_c.png"
PP_LEDGE = "16C85E43_c.png"
PP_TRUNK = "277F8F55_c.png"
PP_CANOPY = "6F4E31BE_c.png"
PP_BUSH_FRONT = "3E251F4C_c.png"
PP_BUSH_BACK = "3E918665_c.png"
PP_HEART = "353C27F1_c.png"
PP_FRINGE = "7FE1C517_c.png"
PP_STONE = "578B0FFC_c.png"
PP_PLAIN = "(none)"

PP_CAM = {"pos": [-0.025, 0.075, 0.6], "at": [-0.025, 0.07, 0.0], "fov": 30}
TILE = 0.0705  # world size of one floor texture tile on the battle stage


# ------------------------------------------------------------- textures

def _find(name: str) -> Path:
    for f in (RENDER / "models").rglob(name):
        return f
    raise FileNotFoundError(name)


def _hex(c: str):
    return [int(c[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]


def tex(name: str) -> str:
    """An original texture, copied as is."""
    TEX.mkdir(exist_ok=True)
    dst = TEX / name
    if not dst.exists():
        Image.open(_find(name)).convert("RGBA").save(dst)
    return f"res://tex/{name}"


def recolor(name: str, out: str, palette: list, gamma=1.0) -> str:
    """Gradient-maps an original texture onto a palette (dark to light)."""
    TEX.mkdir(exist_ok=True)
    im = np.asarray(Image.open(_find(name)).convert("RGBA")).astype(np.float32) / 255.0
    lum = im[..., 0] * 0.3 + im[..., 1] * 0.59 + im[..., 2] * 0.11
    vis = im[..., 3] > 0.5
    lo, hi = np.percentile(lum[vis], 2), np.percentile(lum[vis], 98)
    t = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1) ** gamma
    pal = np.array([_hex(c) for c in palette])
    pos = t * (len(pal) - 1)
    i0 = np.clip(np.floor(pos).astype(int), 0, len(pal) - 2)
    f = (pos - i0)[..., None]
    rgb = pal[i0] * (1 - f) + pal[i0 + 1] * f
    outa = np.concatenate([rgb, im[..., 3:4]], axis=2)
    Image.fromarray((outa * 255 + 0.5).astype(np.uint8), "RGBA").save(TEX / out)
    return f"res://tex/{out}"


def hue(name: str, out: str, degrees: float, sat=1.0, val=1.0) -> str:
    """Hue-rotates an original texture (keeps its pattern and contrast)."""
    TEX.mkdir(exist_ok=True)
    im = Image.open(_find(name)).convert("RGBA")
    a = im.getchannel("A")
    hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(np.float32)
    hsv[..., 0] = (hsv[..., 0] + degrees / 360.0 * 255.0) % 255.0
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    rgb = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
    rgb.putalpha(a)
    rgb.save(TEX / out)
    return f"res://tex/{out}"


def _size(texture: str):
    return Image.open(TEX / texture.split("/")[-1]).size


# --------------------------------------------------------------- pieces

def pp(**kw):
    """The Pleasant Path battle stage, optionally reskinned."""
    d = {"type": "model", "path": PP, "layer": "back"}
    d.update(kw)
    return d


def floor(texture, tint=(1, 1, 1), y=-0.0008, x0=-1.6, x1=1.6, z0=-0.16, z1=0.6, tile=TILE):
    """A wide ground plane that carries the stage floor beyond the screen."""
    w, d = x1 - x0, z1 - z0
    return {"type": "plane", "tex": texture, "pos": [(x0 + x1) / 2, y, (z0 + z1) / 2],
            "size": [w, d], "uv": [w / tile, d / tile], "tint": list(tint), "layer": "back"}


def band(texture, z, depth, tile, y=0.0005):
    """A strip laid on the floor across the whole width (rails, lava...)."""
    return {"type": "plane", "tex": texture, "pos": [0, y, z], "size": [3.2, depth],
            "uv": [3.2 / tile, depth / tile], "layer": "back"}


def card(texture, x, z, h, layer="back", **kw):
    d = {"type": "card", "tex": texture, "pos": [x, kw.pop("y", 0.0), z], "h": h, "layer": layer}
    d.update(kw)
    return d


def box(texture, x, z, size, y=None, layer="back", **kw):
    sx, sy, sz = size
    d = {"type": "box", "tex": texture, "pos": [x, sy / 2 if y is None else y, z],
         "size": [sx, sy, sz], "layer": layer}
    d.update(kw)
    return d


def strip(texture, x0, x1, z, h, layer="back", **kw):
    """A row of the same cut-out repeated along x (bush lines...)."""
    tw, th = _size(texture)
    w = x1 - x0
    reps = max(1.0, round(w / (h * tw / th)))
    return card(texture, (x0 + x1) / 2, z, h, layer, w=w, uv=[reps, 1], **kw)


# ---------------------------------------------------------------- stages

def sphere(texture, x, z, r, layer="back", **kw):
    d = {"type": "sphere", "tex": texture, "pos": [x, kw.pop("y", r), z], "r": r, "layer": layer}
    d.update(kw)
    return d


# Screen geometry with PP_CAM: the left free area spans x -0.40..-0.19 and
# the right one 0.14..0.33 (z -0.15..0.1); bottom corners at z 0.335 are
# x -0.155 / 0.105.
FL, FR, FZ = -0.155, 0.105, 0.335


def jungle_overhang(leaves, frond):
    """Leaf clusters and fronds hanging from above the screen (cards turned
    upside down: they grow downward from `y`), hiding the flat tops of the
    battle stage canopies. The layout below is drawn for z -0.05 (screen top
    at y 0.249, x -0.334..0.284); it is scaled toward the camera to z 0.15,
    in front of the canopies but still behind the Shy Guys."""
    z = 0.15
    cx, cy, k = PP_CAM["pos"][0], PP_CAM["pos"][1], (0.6 - z) / 0.65

    def card(texture, x, z, h, y, **kw):  # noqa: the scaled version
        # the clusters reach 0.012 above the screen so no sky shows through
        return globals()["card"](texture, cx + (x - cx) * k, z, (h + 0.012) * k,
                                 y=cy + (y + 0.012 - cy) * k, **kw)

    out = []
    # (x, top y, height, flip, tilt) of each leaf cluster, left to right
    for x, y, h, fl, tilt in [
        (-0.33, 0.268, 0.075, False, 6), (-0.255, 0.262, 0.06, True, -4),
        (-0.18, 0.27, 0.07, False, 3), (-0.105, 0.262, 0.055, True, -6),
        (-0.035, 0.266, 0.06, False, 4), (0.035, 0.262, 0.055, True, -3),
        (0.105, 0.27, 0.07, False, 5), (0.18, 0.262, 0.06, True, -5),
        (0.25, 0.268, 0.075, False, 3), (0.31, 0.262, 0.06, True, -6),
    ]:
        out.append(card(leaves, x, z, h, y=y, flip=fl, rot_z=180 + tilt))
    # a few fronds dangling lower between the clusters
    for x, h, fl, tilt in [(-0.3, 0.075, False, 8), (-0.215, 0.06, True, -6),
                           (0.145, 0.06, False, 6), (0.27, 0.08, True, -8)]:
        out.append(card(frond, x, z + 0.01, h, y=0.262, flip=fl, rot_z=180 + tilt))
    return out


def stage_defs() -> dict:
    bush = tex("Bush.png")
    big_bush = tex("big bush.png")
    hedge = tex("mac_mac_britshcuttif.png")
    flowers = tex("mac_hanatif.png")
    kusa = tex("mac_kusa1tif.png")
    frost = tex("hos_h_kusa02tif.png")
    defs = {}

    # Pleasant Path: the real battle stage, its floor carried to the sides
    defs["meadow"] = {
        "bg": "pleasant", "bg_y": -40, "camera": PP_CAM,
        "items": [
            pp(hide_tex=[PP_WOOD, PP_FLOOR]),
            floor(PPT + PP_FLOOR, (0.86, 0.9, 0.86)),
            card(bush, -0.31, -0.12, 0.045), card(big_bush, 0.27, -0.14, 0.07, flip=True),
            card(kusa, -0.25, 0.06, 0.032, rect=[0, 0, 1, 0.5]),
            card(kusa, 0.19, 0.05, 0.032, rect=[0, 0, 1, 0.5], flip=True),
            card(bush, FL, FZ, 0.02, "front"), card(bush, FR, FZ, 0.02, "front", flip=True),
        ],
    }

    # Shy Guy's Toy Box: play mat, toy block towers, balls, a toy train track
    mat = recolor("osr_checktif.png", "toy_mat.png", ["#5fa452", "#9fd36d", "#d9f29a"])
    red = hue("mac_toyboxtif.png", "toy_red.png", -48, 1.25)
    blue = hue("mac_toyboxtif.png", "toy_blue.png", 165, 1.1)
    green = hue("mac_toyboxtif.png", "toy_green.png", 70, 1.05)
    yellow = tex("mac_toyboxtif.png")
    rail = tex("mac_mac_railwaytif.png")
    s = 0.05
    defs["toybox"] = {
        "bg": "toybox", "bg_y": -60, "camera": PP_CAM,
        "items": [
            floor(mat, tile=TILE * 1.6),
            band(rail, 0.12, 0.03, 0.03),
            box(red, -0.29, -0.1, (s, s, s), rot=12),
            box(blue, -0.29, -0.1, (s * 0.8,) * 3, y=s + s * 0.4, rot=-8),
            box(yellow, -0.29, -0.1, (s * 0.6,) * 3, y=s * 1.8 + s * 0.3, rot=20),
            box(green, -0.22, 0.0, (s * 0.8,) * 3, rot=-20),
            box(yellow, -0.27, 0.05, (s * 0.7,) * 3, rot=35),
            sphere(blue, -0.19, 0.1, 0.02),
            box(green, 0.24, -0.11, (s * 1.2,) * 3, rot=-10),
            box(red, 0.24, -0.11, (s * 0.8,) * 3, y=s * 1.2 + s * 0.4, rot=14),
            box(blue, 0.2, 0.01, (s * 0.8,) * 3, rot=25),
            box(yellow, 0.15, 0.09, (s * 0.5,) * 3, rot=-30),
            sphere(red, 0.21, 0.1, 0.018),
            box(blue, FL - 0.005, FZ, (0.022,) * 3, "front", rot=20),
            sphere(yellow, FR + 0.01, FZ, 0.011, "front"),
        ],
    }

    # Flower Fields: bright grass, flower beds and blooming bushes
    fgrass = recolor("osr_green_etif.png", "flower_grass.png", ["#2f7d1e", "#5fb534", "#a6df58"])
    defs["flowers"] = {
        "bg": "flowers_sun", "bg_y": -10, "camera": PP_CAM,
        "items": [
            pp(hide_tex=[PP_WOOD, PP_FLOOR, PP_TRUNK, PP_CANOPY, PP_LEDGE, PP_STONE, PP_PLAIN,
                         PP_HEART, PP_FRINGE]),
            floor(fgrass),
            strip(flowers, -0.7, 0.7, -0.155, 0.03),
            card(kusa, -0.30, -0.07, 0.06, rect=[0, 0, 1, 0.5]),
            card(kusa, 0.24, -0.08, 0.06, rect=[0, 0, 1, 0.5], flip=True),
            card(flowers, -0.28, 0.04, 0.036), card(flowers, -0.2, 0.1, 0.026, flip=True),
            card(flowers, 0.22, 0.05, 0.036, flip=True), card(flowers, 0.15, 0.1, 0.026),
            card(flowers, FL, FZ, 0.018, "front"), card(flowers, FR, FZ, 0.018, "front", flip=True),
        ],
    }

    # Dry Dry Desert: sand, layered mesas, sandstone rocks and dead trees
    sand = recolor("osr_green_etif.png", "sand.png", ["#c68a45", "#e4b466", "#f8dc9a"])
    stone = recolor("osr_gake_atif.png", "sandstone.png", ["#8a5a2c", "#c98e4c", "#f0c27a"])
    mesa = recolor("mac_rock_3btif.png", "mesa.png", ["#7a3f1e", "#b8693a", "#e2a066", "#f6d29a"])
    dead = recolor("mac_mac_britshtreetif.png", "dead_tree.png", ["#4a2c18", "#7a4a26", "#a8723c"])
    defs["desert"] = {
        "bg": "dunes_a", "bg_y": -70, "camera": PP_CAM,
        "items": [
            floor(sand, tile=TILE * 1.4),
            box(mesa, -0.33, -0.14, (0.09, 0.19, 0.07), rot=8, uv=[2, 3]),
            box(mesa, 0.28, -0.15, (0.08, 0.15, 0.07), rot=-10, uv=[2, 2.5]),
            box(stone, -0.25, -0.02, (0.05, 0.035, 0.04), rot=20),
            box(stone, 0.2, -0.03, (0.04, 0.03, 0.04), rot=-15),
            box(stone, -0.26, 0.08, (0.03, 0.02, 0.03), rot=-30),
            box(stone, 0.2, 0.08, (0.03, 0.022, 0.03), rot=40),
            card(dead, -0.22, -0.11, 0.14), card(dead, 0.2, -0.1, 0.11, flip=True),
            box(stone, FL - 0.01, FZ, (0.024, 0.014, 0.02), "front", rot=15),
        ],
    }

    # Jade Jungle: dark grass, the forest trees, giant leaves and fronds
    jgrass = recolor("osr_green_etif.png", "jungle_grass.png", ["#123d17", "#24702a", "#4ea43a"])
    frond = recolor("hos_h_ha2tif.png", "frond.png", ["#0a3a1c", "#1f7f39", "#7fd860"])
    leaves = recolor("hos_h_ha6tif.png", "jungle_leaves.png", ["#0b3a1d", "#2a8a3c", "#8be06a"])
    leaf = tex("mac_flokukitif.png")
    defs["jungle"] = {
        "bg": "jungle_a", "bg_y": -20, "camera": PP_CAM,
        "items": [
            pp(hide_tex=[PP_WOOD, PP_FLOOR, PP_LEDGE, PP_STONE, PP_PLAIN],
               tint_tex={PP_CANOPY: [0.7, 0.85, 0.7], PP_BUSH_BACK: [0.85, 1, 0.85]}),
            floor(jgrass),
            card(hedge, -0.31, -0.12, 0.08), card(hedge, 0.27, -0.13, 0.08, flip=True),
            card(frond, -0.21, -0.02, 0.08), card(frond, -0.25, -0.04, 0.065, flip=True),
            card(frond, 0.16, -0.02, 0.08, flip=True), card(frond, 0.2, -0.05, 0.065),
            card(leaves, -0.27, 0.06, 0.04), card(leaves, 0.21, 0.07, 0.04, flip=True),
            card(leaf, FL, FZ, 0.022, "front", rot_z=20),
            card(leaf, FR, FZ, 0.022, "front", flip=True, rot_z=-20),
        ] + jungle_overhang(leaves, frond),
    }

    # Mt. Lavalava: charred rock, a lava river, basalt pillars, burnt trees
    rock = recolor("osr_gake_atif.png", "lava_rock.png", ["#1a0d0e", "#45211d", "#7a3a28"])
    boulder = recolor("osr_gake_atif.png", "boulder.png", ["#24120f", "#5a2c22", "#9a5236"])
    basalt = recolor("mac_rock_3btif.png", "basalt.png", ["#120809", "#3a1d1a", "#6e3426", "#a85a32"])
    lava = recolor("mac_mizutif.png", "lava.png", ["#8f1806", "#e8500f", "#ffb43a", "#fff09a"])
    burnt = recolor("mac_mac_britshtreetif.png", "burnt_tree.png", ["#120a0a", "#2e1a16", "#5a2e22"])
    defs["volcano"] = {
        "bg": "dark_red", "bg_y": -60, "camera": PP_CAM,
        "items": [
            floor(rock, tile=TILE * 1.5),
            band(lava, -0.12, 0.08, 0.05),
            card(burnt, -0.25, -0.17, 0.17), card(burnt, 0.21, -0.17, 0.15, flip=True),
            box(basalt, -0.33, -0.07, (0.07, 0.17, 0.06), rot=12, uv=[1.5, 3]),
            box(basalt, 0.27, -0.08, (0.06, 0.2, 0.06), rot=-15, uv=[1.5, 3.5]),
            box(boulder, -0.24, 0.02, (0.05, 0.035, 0.05), rot=25),
            box(boulder, 0.18, 0.04, (0.045, 0.03, 0.04), rot=-18),
            box(boulder, -0.27, 0.09, (0.03, 0.02, 0.03), rot=-10),
            box(boulder, FL - 0.01, FZ, (0.024, 0.016, 0.02), "front", rot=-20),
        ],
    }

    # Shiver Mountain: snowfield, snowy trees, ice blocks and frosty plants
    snow = recolor("osr_green_etif.png", "snow.png", ["#9fb6dc", "#dde7f6", "#ffffff"], gamma=0.7)
    snowy = recolor(PP_CANOPY, "snow_canopy.png", ["#4f6fa6", "#9fb5dc", "#e4ecf8"])
    ice = recolor("stones.bmp", "ice.png", ["#6f9ad6", "#bcd7f4", "#f4fbff"])
    defs["snow"] = {
        "bg": "snow_peaks", "bg_y": -30, "camera": PP_CAM,
        "items": [
            pp(hide_tex=[PP_WOOD, PP_FLOOR, PP_LEDGE, PP_STONE, PP_PLAIN, PP_HEART, PP_FRINGE,
                         PP_BUSH_BACK, PP_BUSH_FRONT],
               retex={PP_CANOPY: snowy}, novc_tex=[PP_CANOPY]),
            floor(snow),
            box(ice, -0.31, -0.13, (0.07, 0.06, 0.06), rot=14),
            box(ice, 0.26, -0.14, (0.06, 0.09, 0.06), rot=-12),
            card(frost, -0.25, -0.05, 0.045), card(frost, -0.28, 0.06, 0.035, flip=True),
            card(frost, -0.2, 0.1, 0.028),
            card(frost, 0.2, -0.05, 0.045, flip=True), card(frost, 0.22, 0.07, 0.035),
            card(frost, 0.15, 0.1, 0.028, flip=True),
            card(frost, FL, FZ, 0.018, "front"), card(frost, FR, FZ, 0.018, "front", flip=True),
        ],
    }

    # Shooting Star Summit: starry purple ground, blue plants, star stones
    sky_ground = tex("hos_kusa5tif.png")
    hedge_night = tex("hos_hutikusatif.png")
    blue_leaf = tex("hos_h_ha2tif.png")
    blue_leaves = tex("hos_h_ha6tif.png")
    gate = tex("hos_stargatetif.png")
    defs["stars"] = {
        "bg": "stars", "bg_y": -40, "camera": PP_CAM,
        "items": [
            floor(sky_ground, tile=TILE * 1.2),
            strip(hedge_night, -0.7, 0.7, -0.155, 0.02),
            card(gate, -0.3, -0.13, 0.15), card(gate, 0.25, -0.14, 0.13, flip=True),
            card(blue_leaf, -0.24, -0.04, 0.07), card(blue_leaf, -0.27, -0.06, 0.055, flip=True),
            card(blue_leaf, 0.2, -0.03, 0.07, flip=True), card(blue_leaf, 0.23, -0.06, 0.055),
            card(blue_leaves, -0.27, 0.06, 0.035), card(blue_leaves, 0.21, 0.07, 0.035, flip=True),
            card(frost, -0.22, 0.08, 0.028), card(frost, 0.17, 0.09, 0.028, flip=True),
            card(frost, FL, FZ, 0.018, "front"), card(frost, FR, FZ, 0.018, "front", flip=True),
        ],
    }
    # Bowser's Castle: dark stone, a lava moat under a red sky, battlements
    # and towers of castle bricks (Bowser himself stands on the right, see
    # game/src/stage/bowser.gd)
    cfloor = recolor("stones.bmp", "castle_floor.png", ["#100c10", "#2a2026", "#463840", "#66545a"], gamma=1.8)
    brick = recolor("bricks.png", "castle_brick.png", ["#09070b", "#1a1419", "#2d2329", "#463840"], gamma=2.0)
    merlon = (0.026, 0.026, 0.03)
    defs["bowser"] = {
        "bg": "dark_red", "bg_y": -420, "camera": PP_CAM,
        "items": [
            floor(cfloor, tile=TILE * 0.6),
            band(lava, -0.1, 0.11, 0.05),
            # the curtain wall beyond the moat, with its battlements
            box(brick, 0, -0.2, (1.4, 0.045, 0.03), uv=[24, 1]),
            *[box(brick, x, -0.2, merlon, y=0.045 + merlon[1] / 2)
              for x in [-0.66 + 0.06 * i for i in range(23)]],
            # towers
            box(brick, -0.34, -0.16, (0.085, 0.26, 0.085), rot=6, uv=[2, 6]),
            *[box(brick, -0.34 + dx, -0.16 + dz, (0.024, 0.024, 0.024), y=0.272)
              for dx, dz in [(-0.03, -0.03), (0.03, -0.03), (-0.03, 0.03), (0.03, 0.03)]],
            box(brick, 0.3, -0.17, (0.075, 0.2, 0.075), rot=-8, uv=[2, 5]),
            *[box(brick, 0.3 + dx, -0.17 + dz, (0.022, 0.022, 0.022), y=0.211)
              for dx, dz in [(-0.026, -0.026), (0.026, -0.026), (-0.026, 0.026), (0.026, 0.026)]],
            # broken pillars and rubble on this side of the moat
            box(brick, -0.26, -0.01, (0.035, 0.07, 0.035), rot=18, uv=[1, 2]),
            box(brick, -0.22, 0.07, (0.03, 0.02, 0.03), rot=-25),
            box(cfloor, -0.29, 0.09, (0.03, 0.018, 0.025), rot=40),
            box(brick, 0.17, 0.08, (0.028, 0.018, 0.028), rot=30),
            box(brick, FL - 0.01, FZ, (0.024, 0.016, 0.02), "front", rot=-20),
        ],
    }
    return defs
