"""Listens (numerically) to every looping track's wrap point: the end of the
loop spliced back onto its start must not click nor jump in loudness or
timbre. Prints one line per track; exits 1 if a seam looks bad.

    python check_music_seams.py
"""
import json
import sys
from pathlib import Path

import numpy as np

from audio_lib import decode

ROOT = Path(__file__).resolve().parent.parent
SR = 44100


def envelope(x, win=0.05):
    n = int(SR * win)
    m = len(x) // n
    return np.sqrt(np.mean(x[: m * n].reshape(m, n) ** 2, axis=1) + 1e-12)


def spectrum(x):
    w = np.hanning(len(x))
    s = np.abs(np.fft.rfft(x * w))
    bands = np.array_split(s, 24)
    return np.log(np.array([b.mean() for b in bands]) + 1e-6)


def main():
    meta = json.loads((ROOT / "game" / "data" / "music.json").read_text(encoding="utf-8"))
    bad = 0
    for tid, info in meta.items():
        if not isinstance(info, dict) or not info.get("loop") or not info.get("loop_corr"):
            continue
        x = decode(ROOT / "game" / "assets" / "music" / f"{tid}.ogg", SR).mean(axis=1)
        off = int(info["loop_offset"] * SR)
        end = len(x)  # the player wraps at the end of the stream
        span = int(1.5 * SR)
        before, after = x[end - span:end], x[off:off + span]
        y = np.concatenate([before, after])
        # click: sample step at the splice against the typical step nearby
        steps = np.abs(np.diff(y))
        click = steps[span - 1] / (np.percentile(steps, 99) + 1e-9)
        # loudness: the end of the loop vs. what led into its start the first time (dB)
        e_b = envelope(before[-int(0.3 * SR):]).mean()
        e_a = envelope(after[: int(0.3 * SR)]).mean()
        e_n = envelope(x[off - int(0.3 * SR):off]).mean()  # what preceded the start in the first pass
        jump_db = 20 * np.log10((e_n + 1e-9) / (e_b + 1e-9))
        # timbre change: log-spectrum distance across the seam vs. within the loop
        n = int(0.25 * SR)
        d_seam = np.abs(spectrum(before[-n:]) - spectrum(after[:n])).mean()
        ref = []
        for k in range(1, 6):
            p = off + k * (end - off) // 6
            ref.append(np.abs(spectrum(x[p - n:p]) - spectrum(x[p:p + n])).mean())
        ratio = d_seam / (np.median(ref) + 1e-9)
        flag = click > 1.5 or abs(jump_db) > 8 or ratio > 2.2
        bad += flag
        print(f"{tid:16s} corr {info['loop_corr']:.2f}  click {click:4.2f}  jump {jump_db:+5.1f} dB  "
              f"timbre x{ratio:4.2f}  {'CHECK' if flag else 'ok'}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
