#!/bin/sh
# Paper Tetris: adds the game to your applications menu, with its icon.
# Nothing needs root: everything goes into your home folder.
#
#   sh install.sh               install (or update) for the current user
#   sh install.sh --uninstall   remove it again
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
DEST="$DATA/paper-tetris"
DESKTOP="$DATA/applications/paper-tetris.desktop"
ICONS="$DATA/icons/hicolor"

refresh() {
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$ICONS" || true
}

if [ "$1" = "--uninstall" ]; then
  rm -rf "$DEST" "$DESKTOP"
  rm -f "$ICONS"/*/apps/paper-tetris.png
  refresh
  echo "Paper Tetris removed."
  exit 0
fi

mkdir -p "$DEST" "$DATA/applications"
cp "$HERE/PaperTetris.x86_64" "$DEST/PaperTetris.x86_64"
chmod +x "$DEST/PaperTetris.x86_64"
for f in "$HERE"/icons/paper-tetris_*.png; do
  n=$(basename "$f" .png); n=${n#paper-tetris_}
  mkdir -p "$ICONS/${n}x${n}/apps"
  cp "$f" "$ICONS/${n}x${n}/apps/paper-tetris.png"
done
cp "$HERE/icons/paper-tetris_256.png" "$DEST/icon.png"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Paper Tetris
Comment=Classic Tetris folded into a Paper Mario 64 storybook
Comment[fr]=Le Tetris classique plié dans un livre d'images Paper Mario 64
Exec="$DEST/PaperTetris.x86_64"
Path=$DEST
Icon=paper-tetris
Terminal=false
Categories=Game;BlocksGame;
Keywords=tetris;puzzle;blocks;paper;mario;
StartupWMClass=Paper Tetris
EOF
chmod +x "$DESKTOP"
refresh
echo "Paper Tetris installed: look for it in your applications menu."
echo "(Game files in $DEST. To remove: sh install.sh --uninstall)"
