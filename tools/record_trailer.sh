#!/bin/sh
# Records the trailer footage with Godot's Movie Maker (1080p, 30 fps, game
# music muted so one track can be laid over the cut), renders the caption
# cards, then cuts the trailer and the README GIF (tools/make_trailer.py).
#
#   sh tools/record_trailer.sh <footage dir>
set -e
cd "$(dirname "$0")/.."
OUT=${1:?footage directory}
G=${G:-tools/bin/godot/Godot_v4.7.2-stable_win64_console.exe}
mkdir -p "$OUT/cards"
# the window override in project.godot is 1600x900: record at 1080p
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n\n[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' > game/override.cfg
trap 'rm -f game/override.cfg' EXIT

rec() {
	name=$1; secs=$2; shift 2
	"$G" --path game --write-movie "$OUT/$name.avi" --fixed-fps 30 res://tests/capture.tscn -- \
		lang=en music=0 shots="$secs" out="$OUT/x_$name" "$@"
}
GAME="scene=res://src/game/game.tscn mode=marathon"
rec title 7 scene=res://src/menu/main_menu.tscn
for s in toybox meadow flowers desert jungle volcano snow stars; do
	rec "st_$s" 11 $GAME stage=$s start_level=5 demo=well bot=smart seed=3
done
rec perfect 8 $GAME stage=jungle start_level=6 demo=perfect bot=smart seed=5
rec gameover 15 $GAME stage=snow start_level=8 demo=danger bot=1 bot_rate=0.45 seed=9
rec touch 10 $GAME stage=meadow start_level=4 demo=well bot=smart seed=11 "inputs=0.3:tap@960;300"
rec menu 13 scene=res://src/menu/main_menu.tscn \
	"inputs=2.2:ui_accept,3.2:ui_down,3.6:ui_accept,4.4:ui_down,4.9:ui_down,5.4:ui_down,5.9:ui_down,6.6:ui_cancel,7.2:ui_down,7.5:ui_down,8.0:ui_accept,8.8:ui_right,9.8:ui_down,10.3:ui_down,11.0:ui_cancel"

"$G" --path game res://tests/trailer_cards.tscn -- out="$OUT/cards"
python tools/make_trailer.py "$OUT" dist/trailer
