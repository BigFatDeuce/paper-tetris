#!/bin/sh
# Builds every release into dist/: web (for the site), Windows, Linux,
# macOS and Android, then zips the desktop builds for GitHub Releases.
#   sh tools/export_all.sh [web|windows|linux|macos|android ...]
# The APK is signed with the key in $GODOT_ANDROID_KEYSTORE_RELEASE_PATH
# (falls back to Godot's debug keystore; set the 3 variables for your own).
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
G="$ROOT/tools/bin/godot/Godot_v4.7.2-stable_win64_console.exe"
VERSION=$(grep '^config/version=' game/project.godot | cut -d'"' -f2)
TARGETS=${*:-web windows linux macos android}
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:=$APPDATA/Godot/keystores/debug.keystore}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:=androiddebugkey}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:=android}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

"$G" --headless --path game --import >/dev/null 2>&1
for t in $TARGETS; do
  case $t in
    web) preset="Web"; out="dist/web/index.html" ;;
    windows) preset="Windows"; out="dist/windows/PaperTetris.exe" ;;
    linux) preset="Linux"; out="dist/linux/PaperTetris.x86_64" ;;
    macos) preset="macOS"; out="dist/macos/PaperTetris-macOS.zip" ;;
    android) preset="Android"; out="dist/android/PaperTetris.apk" ;;
    *) echo "unknown target $t"; exit 1 ;;
  esac
  rm -rf "$(dirname "$out")"; mkdir -p "$(dirname "$out")"
  echo "== $preset"
  "$G" --headless --path game --export-release "$preset" "$ROOT/$out" 2>&1 | grep -E "ERROR|error|WARNING: .*export" | grep -v "resources still in use" 
  [ -f "$out" ] || { echo "!! $preset export failed"; exit 1; }
  if [ "$t" = linux ]; then
    # an ELF has no icon: install.sh adds a menu entry with the desktop icons
    cp tools/linux/install.sh dist/linux/
    cp -r tools/linux/icons dist/linux/
  fi
  ls -la "$(dirname "$out")" | tail -n +2
done

# release archives
mkdir -p dist/release
case " $TARGETS " in *" windows "*) (cd dist/windows && python -c "import shutil;shutil.make_archive('../release/PaperTetris-$VERSION-windows','zip','.')") ;; esac
# the Linux zip keeps the executable bits (zipped on Windows, none are set)
case " $TARGETS " in *" linux "*) python tools/zip_linux.py dist/linux "dist/release/PaperTetris-$VERSION-linux.zip" ;; esac
case " $TARGETS " in *" macos "*) cp dist/macos/PaperTetris-macOS.zip "dist/release/PaperTetris-$VERSION-macos.zip" ;; esac
case " $TARGETS " in *" android "*) cp dist/android/PaperTetris.apk "dist/release/PaperTetris-$VERSION-android.apk" ;; esac
ls -la dist/release
