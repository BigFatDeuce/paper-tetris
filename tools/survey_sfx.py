"""Spectrogram contact sheets of the PM64 sample banks (to audition by eye)."""
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from paths import SAMPLES  # noqa: E402
OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)


def read(path):
    with wave.open(str(path)) as w:
        sr, ch, n, sw = w.getframerate(), w.getnchannels(), w.getnframes(), w.getsampwidth()
        raw = w.readframes(n)
    a = np.frombuffer(raw, dtype=np.int16 if sw == 2 else np.uint8).astype(np.float32)
    if sw == 1:
        a = (a - 128) * 256
    a = a.reshape(-1, ch).mean(axis=1) / 32768.0
    return a, sr


def spectro(a, sr, w=200, h=90, max_t=1.6):
    nfft = 256
    hop = 64
    if len(a) < nfft:
        a = np.pad(a, (0, nfft - len(a)))
    n = 1 + (len(a) - nfft) // hop
    idx = np.arange(nfft)[None, :] + hop * np.arange(n)[:, None]
    s = np.abs(np.fft.rfft(a[idx] * np.hanning(nfft), axis=1)).T
    s = 20 * np.log10(s + 1e-6)
    s = np.clip((s + 60) / 60, 0, 1)
    s = s[::-1]
    img = Image.fromarray((s * 255).astype(np.uint8), "L")
    tw = int(min(1.0, (len(a) / sr) / max_t) * w)
    img = img.resize((max(tw, 2), h))
    out = Image.new("L", (w, h), 0)
    out.paste(img, (0, 0))
    # waveform envelope overlay
    return out.convert("RGB")


def sheet(files, name, cols=8):
    cw, ch = 210, 112
    rows = (len(files) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * cw, rows * ch), (30, 30, 40))
    d = ImageDraw.Draw(canvas)
    for k, f in enumerate(files):
        a, sr = read(f)
        dur = len(a) / sr
        sp = spectro(a, sr)
        x, y = (k % cols) * cw, (k // cols) * ch
        canvas.paste(sp, (x + 5, y + 18))
        stem = f.stem.replace("BANK_", "").replace("_INSTR_", ":").replace("_SND_0000", "")
        d.text((x + 5, y + 3), f"{stem[:24]} {dur:.2f}s", fill=(255, 255, 0))
    canvas.save(OUT / f"{name}.png")


banks = sys.argv[2].split(",") if len(sys.argv) > 2 else ["17", "18", "19", "1A", "1B", "1C"]
files = []
for b in banks:
    files += sorted((SAMPLES / "sfx").glob(f"BANK_{b}_*.wav"))
sheet(files, "sfx_" + "_".join(banks))
print(len(files))
