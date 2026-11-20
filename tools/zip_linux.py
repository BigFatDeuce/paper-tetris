"""Zips the Linux build with Unix permissions, so PaperTetris.x86_64 and
install.sh stay executable once unzipped (a zip made on Windows has none).

    python zip_linux.py dist/linux dist/release/PaperTetris-x.y.z-linux.zip
"""
import sys
import zipfile
from pathlib import Path

EXECUTABLE = {"PaperTetris.x86_64", "install.sh"}


def main(src: str, dst: str):
    src_dir = Path(src)
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(src_dir.rglob("*")):
            if f.is_dir():
                continue
            info = zipfile.ZipInfo.from_file(f, f.relative_to(src_dir).as_posix())
            info.create_system = 3                      # Unix, so the mode is honoured
            mode = 0o755 if f.name in EXECUTABLE else 0o644
            info.external_attr = (0o100000 | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(f, "rb") as fh:
                z.writestr(info, fh.read())


if __name__ == "__main__":
    main(*sys.argv[1:3])
