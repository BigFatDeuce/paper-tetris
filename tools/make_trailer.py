"""Cuts the 45-second YouTube trailer and the README GIF out of footage
recorded with Godot's Movie Maker (see tools/record_trailer.sh), with the
caption cards rendered by game/tests/trailer_cards.tscn and Bowser's battle
theme ("Bowser, My Old Enemy!", from the original soundtrack rips, see
tools/paths.py) laid over the whole thing.

    python make_trailer.py <footage dir> [out dir]

Needs ffmpeg on the PATH.
"""
import subprocess
import sys
from pathlib import Path

from paths import OST

ROOT = Path(__file__).resolve().parent.parent
MUSIC = OST / "Mario Story Original Sound Track - Yuka Tsujiyoko - Bowser, My Old Enemy!.flac"
# the OST master is loud (-10.4 LUFS): music around -15.5 LUFS, the game's
# sound effects (about -15.5 LUFS in the footage) 9 dB under it
MUSIC_GAIN = 0.556
SFX_GAIN = 0.355
FPS = 30

# (clip, start, end, caption card or None, stage tag or None)
SHOTS = [
    ("title", 0.2, 4.2, None, None),
    ("st_toybox", 2.6, 6.1, "classic", None),
    ("st_meadow", 2.8, 5.8, "storybook", None),
    ("st_flowers", 3.45, 4.95, None, "flowers"),
    ("st_desert", 3.45, 4.95, None, "desert"),
    ("st_jungle", 3.45, 4.95, None, "jungle"),
    ("st_volcano", 3.45, 4.95, None, "volcano"),
    ("st_snow", 3.45, 4.95, None, "snow"),
    ("st_stars", 3.45, 4.95, None, "stars"),
    ("perfect", 2.8, 6.8, "juice", None),
    ("gameover", 3.6, 6.1, "troupe", None),
    ("gameover", 11.0, 13.5, None, None),
    ("menu", 3.0, 5.4, "modes", None),
    ("menu", 8.3, 10.9, None, None),
    ("touch", 3.0, 7.5, "anywhere", None),
    ("title", 0.4, 7.0, "play", None),
]
END_HOLD = 0.5          # the last frame holds a little before the fade
# captions that run across several shots: card -> number of shots it covers
SPAN = {"troupe": 2, "modes": 2}


def run(cmd):
    print(" ".join(str(c) for c in cmd[:6]), "...")
    subprocess.run([str(c) for c in cmd], check=True)


def trailer(src: Path, out: Path):
    cards = src / "cards"
    # one input per shot (a stream can only feed the filter graph once);
    # -ss before -i seeks quickly to the shot
    inputs = []
    for clip, a, b, _cap, _tag in SHOTS:
        inputs += ["-ss", f"{max(0.0, a - 1.0):.3f}", "-i", src / f"{clip}.avi"]
    f = []
    starts = []
    t = 0.0
    for n, (clip, a, b, _cap, _tag) in enumerate(SHOTS):
        i = n
        a, b = a - max(0.0, a - 1.0), b - max(0.0, a - 1.0)
        hold = f",tpad=stop_mode=clone:stop_duration={END_HOLD}" if n == len(SHOTS) - 1 else ""
        f.append(f"[{i}:v]trim={a}:{b},setpts=PTS-STARTPTS,fps={FPS}{hold}[v{n}]")
        pad = f",apad=pad_dur={END_HOLD}" if n == len(SHOTS) - 1 else ""
        # 15 ms fades: no clicks at the cuts
        d = b - a
        f.append(f"[{i}:a]atrim={a}:{b},asetpts=PTS-STARTPTS,afade=t=in:d=0.015,"
                 f"afade=t=out:st={d - 0.015:.3f}:d=0.015{pad}[a{n}]")
        starts.append(t)
        t += d
    total = t + END_HOLD
    f.append("".join(f"[v{n}][a{n}]" for n in range(len(SHOTS))) + f"concat=n={len(SHOTS)}:v=1:a=1[cv][ca]")

    # caption cards: pop in from slightly above, fade out
    overlays = []
    for n, (_clip, _a, _b, cap, tag) in enumerate(SHOTS):
        for card, kind in ((cap, "cap"), (f"stage_{tag}" if tag else None, "tag")):
            if not card:
                continue
            st = starts[n] + (0.25 if kind == "cap" else 0.1)
            span = SPAN.get(card, 1)
            end = starts[n + span - 1] + (SHOTS[n + span - 1][2] - SHOTS[n + span - 1][1]) if n + span - 1 < len(SHOTS) else total
            if n == len(SHOTS) - 1:
                end = total - 0.6
            dur = end - st - 0.1
            overlays.append((card, st, dur, kind))
    for card in ("legal",):
        overlays.append((card, starts[-1] + 0.8, total - starts[-1] - 1.4, "legal"))
    base = len(SHOTS)
    cur = "cv"
    for k, (card, st, dur, kind) in enumerate(overlays):
        inputs += ["-loop", "1", "-t", f"{dur:.3f}", "-i", src / "cards" / f"{card}.png"]
        j = base + k
        f.append(f"[{j}:v]format=rgba,fade=t=in:d=0.2:alpha=1,fade=t=out:st={dur - 0.2:.3f}:d=0.2:alpha=1,"
                 f"setpts=PTS-STARTPTS+{st:.3f}/TB[c{k}]")
        slide = "0" if kind == "legal" else f"if(lt(t-{st:.3f},0.22),-36*(1-(t-{st:.3f})/0.22),0)"
        if kind == "tag":
            slide = f"if(lt(t-{st:.3f},0.22),60*(1-(t-{st:.3f})/0.22),0)"
        f.append(f"[{cur}][c{k}]overlay=x=0:y='{slide}':eof_action=pass[o{k}]")
        cur = f"o{k}"
    f.append(f"[{cur}]fade=t=in:d=0.4,fade=t=out:st={total - 1.0:.3f}:d=1.0,format=yuv420p[vout]")

    m = base + len(overlays)
    inputs += ["-i", MUSIC]
    f.append(f"[{m}:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,volume={MUSIC_GAIN},"
             f"afade=t=out:st={total - 2.5:.3f}:d=2.5[mus]")
    f.append(f"[ca]volume={SFX_GAIN},afade=t=out:st={total - 1.2:.3f}:d=1.2[sfx]")
    f.append("[mus][sfx]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[aout]")

    out.mkdir(parents=True, exist_ok=True)
    graph = out / "trailer_graph.txt"
    graph.write_text(";\n".join(f), encoding="utf-8")
    dst = out / "paper_tetris_trailer.mp4"
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs, "-/filter_complex", graph,
         "-map", "[vout]", "-map", "[aout]", "-c:v", "libx264", "-preset", "slow", "-crf", "17",
         "-profile:v", "high", "-r", FPS, "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
         "-movflags", "+faststart", dst])
    print(f"trailer: {dst} ({total:.2f} s)")


# README loop: four stages, four big clears
GIF = [("st_toybox", 3.3, 5.4), ("st_flowers", 3.3, 5.4), ("perfect", 3.3, 5.6), ("st_volcano", 3.3, 5.4)]


def gif(src: Path, out: Path, width=600, fps=15):
    inputs, f = [], []
    for n, (clip, a, b) in enumerate(GIF):
        inputs += ["-i", src / f"{clip}.avi"]
        f.append(f"[{n}:v]trim={a}:{b},setpts=PTS-STARTPTS,fps={fps},scale={width}:-1:flags=lanczos[g{n}]")
    f.append("".join(f"[g{n}]" for n in range(len(GIF))) + f"concat=n={len(GIF)}:v=1:a=0,split[s0][s1]")
    f.append("[s0]palettegen=max_colors=160:stats_mode=diff[p]")
    f.append("[s1][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle[gout]")
    dst = out / "gameplay.gif"
    run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(f), "-map", "[gout]", "-loop", "0", dst])
    print(f"gif: {dst} ({dst.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    src = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "dist" / "trailer"
    what = sys.argv[3] if len(sys.argv) > 3 else "all"
    if what in ("all", "trailer"):
        trailer(src, out)
    if what in ("all", "gif"):
        gif(src, out)
