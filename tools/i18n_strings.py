"""Lists the user-facing string literals of the game scripts and checks
them against data/lang/fr.json.

    python i18n_strings.py          # missing translations
    python i18n_strings.py --all    # every candidate string
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "game"
# identifiers, paths, node names, actions... never shown to the player
SKIP = re.compile(r"^(res|user)://|^[a-z0-9_]+$|^[A-Z][a-z]+[A-Z]\w*$|^ui_|^game_|\.(png|ogg|wav|json|tscn|gd)$")
NOT_UI = {"Text", "Value", "Content", "Director", "StageFront", "BoardRoot", "Stilt", "CaptureHelper",
          "PM ", "Btn %d", "%d FPS", "%d ms", "LB", "RB", "LS", "RS", "D-Up", "D-Down", "D-Left",
          "D-Right", "Start", "Back", "B2B"}


def literals(src: str):
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
        elif c in "\"'":
            triple = src[i:i + 3] == c * 3
            q = c * 3 if triple else c
            j = i + len(q)
            out = []
            while j < n and src[j:j + len(q)] != q:
                if src[j] == "\\" and j + 1 < n:
                    out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\"}.get(src[j + 1], src[j + 1]))
                    j += 2
                else:
                    out.append(src[j])
                    j += 1
            yield "".join(out)
            i = j + len(q)
        else:
            i += 1


def candidates():
    found = {}
    for f in sorted(ROOT.glob("src/**/*.gd")):
        prev = ""
        src = f.read_text(encoding="utf-8")
        for s in literals(src):
            if s in NOT_UI or SKIP.search(s) or not re.search(r"[A-Za-z]{2}", s):
                continue
            # dictionary keys / ids are lowercase words; UI text is capitalised or has spaces
            if not (s[0].isupper() or " " in s or "%" in s or "\n" in s):
                continue
            found.setdefault(s, f.relative_to(ROOT).as_posix())
    return found


def main():
    found = candidates()
    fr = json.loads((ROOT / "data" / "lang" / "fr.json").read_text(encoding="utf-8")) \
        if (ROOT / "data" / "lang" / "fr.json").exists() else {}
    show = found if "--all" in sys.argv else {k: v for k, v in found.items() if k not in fr}
    for k, v in sorted(show.items(), key=lambda kv: kv[1]):
        print(f"{v:40s} {json.dumps(k, ensure_ascii=False)}")
    print(f"{len(show)} / {len(found)}", file=sys.stderr)


if __name__ == "__main__":
    main()
