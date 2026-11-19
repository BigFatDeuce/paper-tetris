"""Where the original rips live (sprite sheets, soundtrack, samples).

They are not part of the repository. Point the pipelines at them with the
PAPER_TETRIS_SRC environment variable, or put the folder path in a
tools/source_path.txt file (ignored by git). Default: <repo>/source_assets.
"""
import os
from pathlib import Path

_HERE = Path(__file__).resolve().parent


def source_dir() -> Path:
    env = os.environ.get("PAPER_TETRIS_SRC")
    if env:
        return Path(env)
    local = _HERE / "source_path.txt"
    if local.exists():
        return Path(local.read_text(encoding="utf-8").strip())
    return _HERE.parent / "source_assets"


SRC = source_dir()
OST = SRC / "[2000] Mario Story Original Sound Track (Paper Mario)  [FMCN-1002] [FLAC]"
SAMPLES = SRC / "Samples"
