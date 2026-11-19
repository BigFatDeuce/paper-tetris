"""Cuts the title prompts out of the Paper Mario title screen sheet:
PRESS START (English) and COMMENCER PARTIE (French)."""
from pathlib import Path

from PIL import Image

from sprites_lib import SRC

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "sprites" / "ui"
SHEET = SRC / "Nintendo 64 - Paper Mario - Miscellaneous - Title Screen.png"
CUTS = {
    "press_start_en": (132, 180, 253, 199),
    "press_start_fr": (258, 222, 391, 238),
}


def main():
    im = Image.open(SHEET).convert("RGBA")
    for name, (x0, y0, x1, y1) in CUTS.items():
        im.crop((x0 - 1, y0 - 1, x1 + 1, y1 + 1)).save(OUT / f"{name}.png")
        print(name, x1 - x0 + 2, y1 - y0 + 2)


if __name__ == "__main__":
    main()
