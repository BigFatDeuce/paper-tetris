"""Convert the selected OST tracks (FLAC) into seamless-looping OGG files.

For every track we find the point where the CD recording repeats itself,
cut the file at the end of the first full loop, bake a tiny crossfade at
the seam, normalise loudness, and encode Ogg Vorbis. Loop metadata goes to
game/data/music.json (read by the AudioManager at runtime).

Usage: python build_music.py [track_id ...]
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

from audio_lib import decode, find_loop, track_path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "music"
CATALOG = ROOT / "game" / "data" / "music.json"
SR = 44100

# id -> (OST title, display name, loop?)  -- the display names are shown in the jukebox.
TRACKS = {
    "menu_toybox": ("Shy Guy's Toy Box", "Shy Guy's Toy Box", True),
    "stage_toybox": ("Go! Go! By Toy Train", "Go! Go! By Toy Train", True),
    "stage_meadow": ("Over Field and Stream", "Over Field and Stream", True),
    "stage_flowers": ("Flower Rondo", "Flower Rondo", True),
    "stage_desert": ("Traversing Dry-Dry Desert", "Traversing Dry-Dry Desert", True),
    "stage_jungle": ("The Neverending Jungle by the Waterside", "Jungle by the Waterside", True),
    "stage_volcano": ("The Burning Hot Volcano Cavern", "Burning Hot Volcano Cavern", True),
    "stage_snow": ("Shiver Snowfield", "Shiver Snowfield", True),
    "stage_stars": ("Shooting Star Summit", "Shooting Star Summit", True),
    "mode_sprint": ("A Shy Guy Riot - There's Trouble in the City!", "A Shy Guy Riot!", True),
    "mode_ultra": ("Fall in Step and Let's Go", "Fall in Step and Let's Go", True),
    "results_clear": ("Now That That's Over With...", "Now That That's Over With...", True),
    "results_over": ("Downhearted Peach", "Downhearted Peach", True),
    "credits": ("The Parade Continues", "The Parade Continues", True),
    "extra_forest": ("Lost in the Forever Forest", "Lost in the Forever Forest", True),
    "extra_crystal": ("Crystal Palace", "Crystal Palace", True),
    "extra_koopa": ("Koopa Village", "Koopa Village", True),
    "extra_goomba": ("Sunny Goomba Village", "Sunny Goomba Village", True),
    "extra_starroad": ("Star Road", "Star Road", True),
    "extra_party": ("Princess Peach's Party", "Princess Peach's Party", True),
    "extra_general": ("General Guy Appears", "General Guy Appears", True),
    "extra_peaceful": ("Peaceful Mushroom Kingdom", "Peaceful Mushroom Kingdom", True),
    "extra_outpost": ("Dry-Dry Outpost", "Dry-Dry Outpost", True),
    "extra_shiver": ("Snow Falls on Shiver City", "Snow Falls on Shiver City", True),
    "extra_beginning": ("It's the Beginning!", "It's the Beginning!", True),
    "extra_train": ("Mt. Rugged's Pretty Rugged", "Mt. Rugged's Pretty Rugged", True),
}

TARGET_RMS_DB = -17.0
XFADE = int(0.045 * SR)


def write_wav(path: Path, data: np.ndarray):
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def process(tid: str, catalog: dict):
    title, display, want_loop = TRACKS[tid]
    path = track_path(title)
    stereo = decode(path, SR)
    lo = decode(path, 11025, mono=True)
    total = len(stereo)
    info = {"title": display, "source": title}
    loop_start = 0
    end = total
    if want_loop:
        r = find_loop(stereo, SR, lo, 11025)
        if r and r["corr"] >= 0.55:
            loop_start = int((r["start"] + 0.35) * SR)
            lag = int(r["lag"])
            end = loop_start + lag
            # bake crossfade so that sample end-1 -> loop_start is continuous
            n = min(XFADE, loop_start)
            w = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
            seg_end = stereo[end - n:end].copy()
            seg_pre = stereo[loop_start - n:loop_start]
            stereo = stereo[:end].copy()
            stereo[end - n:end] = seg_end * (1.0 - w) + seg_pre * w
            info.update(loop=True, loop_offset=round(loop_start / SR, 6), loop_length=round(lag / SR, 4),
                        loop_corr=round(r["corr"], 4), loop_run=round(float(r["run"]), 1))
        else:
            # no repeat found: keep whole track, fade the end, loop from start
            info.update(loop=True, loop_offset=0.0, loop_length=round(total / SR, 3), loop_corr=0.0)
    # loudness normalisation (RMS on the looped part, peak-safe)
    body = stereo[loop_start:end] if end > loop_start else stereo
    rms = float(np.sqrt(np.mean(body ** 2)) + 1e-9)
    gain = 10 ** (TARGET_RMS_DB / 20) / rms
    peak = float(np.max(np.abs(stereo))) * gain
    if peak > 0.98:
        gain *= 0.98 / peak
    stereo = stereo * gain
    info["gain_db"] = round(20 * np.log10(gain), 2)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "t.wav"
        write_wav(wav, stereo)
        ogg = OUT_DIR / f"{tid}.ogg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)],
                       check=True)
    info["file"] = f"res://assets/music/{tid}.ogg"
    info["duration"] = round(len(stereo) / SR, 3)
    catalog[tid] = info
    print(f"{tid:16s} loop@{info.get('loop_offset', 0):7.2f}s len {info.get('loop_length', 0):7.2f}s "
          f"corr {info.get('loop_corr', 0):.3f} gain {info['gain_db']:+.1f} dB")


def main():
    ids = sys.argv[1:] or list(TRACKS)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {}
    for tid in ids:
        process(tid, catalog)
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    ordered = {k: catalog[k] for k in TRACKS if k in catalog}
    CATALOG.write_text(json.dumps(ordered, indent=1, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
