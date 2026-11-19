"""Touch-screen buttons cut from the Paper Mario HUD sheet: the N64 stick
(move / soft drop), A and B (rotations), C-down (hard drop), Z (hold).
Each button has an "up" and a pressed "down" sprite."""
from pathlib import Path

from PIL import Image

from sprites_lib import SRC

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "sprites" / "ui"
SHEET = SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Battle Extras & HUD.png"
CUTS = {
    "touch_stick_tilt": (19, 42, 58, 68),
    "touch_stick_up": (69, 40, 99, 68),
    "touch_stick_top": (142, 79, 172, 107),
    "touch_a_down": (19, 80, 60, 111),
    "touch_a_up": (63, 77, 104, 111),
    "touch_b_down": (19, 116, 60, 147),
    "touch_b_up": (63, 113, 104, 147),
    "touch_c_down": (108, 118, 147, 147),
    "touch_c_up": (150, 115, 189, 147),
    "touch_z": (175, 70, 187, 84),
}


def main():
    im = Image.open(SHEET).convert("RGBA")
    for name, (x0, y0, x1, y1) in CUTS.items():
        im.crop((x0, y0, x1, y1)).save(OUT / f"{name}.png")
    print(len(CUTS), "touch sprites")


if __name__ == "__main__":
    main()
