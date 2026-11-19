"""The "PAPER" half of the title logo: chunky cut-out letters, each on its
own slightly tilted cream sticker, matching logo_tetris.png."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from build_ui_art import OUT, apply_grain, fill_holes

FONT = Path("C:/Windows/Fonts/ariblk.ttf")
SS = 4
COLORS = ["d8402c", "f2b51c", "3a7bd8", "3f9d3c", "b05ce0"]
TILTS = [-6, 4, -3, 5, -4]
LIFT = [4, -6, 2, -4, 6]


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def letter(ch, color, size=150):
    font = ImageFont.truetype(str(FONT), size * SS)
    box = font.getbbox(ch)
    w = box[2] - box[0] + 60 * SS
    h = box[3] - box[1] + 60 * SS
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).text((30 * SS - box[0], 30 * SS - box[1]), ch, font=font, fill=255)
    # glyph body with a lighter top half and dark outline
    rgb = hexrgb(color)
    light = tuple(min(255, int(c * 1.18 + 30)) for c in rgb)
    body = Image.new("RGBA", (w, h), rgb + (255,))
    grad = Image.linear_gradient("L").resize((w, h))
    top = Image.new("RGBA", (w, h), light + (255,))
    body = Image.composite(body, top, grad.point(lambda v: 255 if v > 120 else int(v * 2.1)))
    body.putalpha(m)
    outline = m.filter(ImageFilter.MaxFilter(4 * SS + 1))
    back = outline.filter(ImageFilter.MaxFilter(12 * SS + 1)).filter(ImageFilter.GaussianBlur(3 * SS)).point(
        lambda v: 255 if v > 100 else 0)
    back = fill_holes(back)
    back_ol = back.filter(ImageFilter.MaxFilter(3 * SS + 1))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ol = Image.new("RGBA", (w, h), (60, 34, 18, 255))
    ol.putalpha(back_ol)
    out.alpha_composite(ol)
    bk = Image.new("RGBA", (w, h), (250, 243, 222, 255))
    bk.putalpha(back)
    out.alpha_composite(bk)
    ink = Image.new("RGBA", (w, h), (58, 32, 16, 255))
    ink.putalpha(outline)
    out.alpha_composite(ink)
    out.alpha_composite(body)
    # small gloss stroke
    gl = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(gl)
    gd.rounded_rectangle([int(w * 0.28), int(h * 0.24), int(w * 0.5), int(h * 0.3)], 6 * SS, fill=150)
    gl = Image.fromarray(np.minimum(np.array(gl), np.array(m.filter(ImageFilter.MinFilter(6 * SS + 1)))))
    shine = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    shine.putalpha(gl)
    out.alpha_composite(shine)
    return out


def main():
    parts = []
    for i, ch in enumerate("PAPER"):
        img = letter(ch, COLORS[i])
        img = img.rotate(TILTS[i], resample=Image.BICUBIC, expand=True)
        parts.append(img)
    gap = -40 * SS
    width = sum(p.width for p in parts) + gap * (len(parts) - 1) + 60 * SS
    height = max(p.height for p in parts) + 60 * SS
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 30 * SS
    for i, p in enumerate(parts):
        y = (height - p.height) // 2 + LIFT[i] * SS
        # shadow
        a = p.getchannel("A").filter(ImageFilter.GaussianBlur(7 * SS))
        sh = Image.new("RGBA", p.size, (50, 25, 10, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.5)))
        canvas.alpha_composite(sh, (x + 12 * SS, y + 14 * SS))
        canvas.alpha_composite(p, (x, y))
        x += p.width + gap
    bbox = canvas.getbbox()
    canvas = canvas.crop(bbox)
    final = canvas.resize((canvas.width // SS, canvas.height // SS), Image.LANCZOS)
    final = apply_grain(final, 5, 11)
    final.save(OUT / "logo_paper.png")
    print("logo_paper", final.size)


if __name__ == "__main__":
    main()
