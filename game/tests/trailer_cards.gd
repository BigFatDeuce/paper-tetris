extends Node
## Renders the trailer captions as transparent 1920x1080 PNGs, drawn with the
## game's own paper windows and Paper Mario fonts, to be laid over gameplay
## footage (tools/make_trailer.py). Usage:
##   godot --path . res://tests/trailer_cards.tscn -- out=C:/tmp/cards

const STAGES := ["toybox", "meadow", "flowers", "desert", "jungle", "volcano", "snow", "stars"]

## id -> [tab title, tab colour, lines, anchor ("top", "bottom", "center", "corner")]
const CARDS := {
	"classic": ["CLASSIC TETRIS", "red", ["SRS rotation, 7-bag, hold, ghost,", "T-Spins, combos and Back-to-Back"], "top"],
	"storybook": ["PAPER MARIO 64 STYLE", "gold", ["Real battle stages from the N64 game,", "rebuilt in 3D from the original models"], "top"],
	"troupe": ["STARRING THE SHY GUYS", "blue", ["They cheer, panic, nap and fall flat...", "but they never touch the board"], "top"],
	"juice": ["NICE!  SUPER!  100%!", "purple", ["Coins, stars, confetti", "and the original soundtrack"], "top"],
	"modes": ["5 MODES", "green", ["Marathon, Sprint,", "Ultra, Endless,", "Practice", "English & français"], "left"],
	"anywhere": ["PLAY ANYWHERE", "red", ["Web, Windows, Linux, macOS, Android", "Keyboard, gamepad or touch"], "top"],
	"play": ["FREE TO PLAY", "gold", ["paper-tetris.holy-c.men", "github.com/BigFatDeuce/paper-tetris"], "bottom"],
}
const LEGAL := "Unofficial fan game, free and non-commercial.  Paper Mario (c) Nintendo / Intelligent Systems.  Tetris (c) The Tetris Company."

var _vp: SubViewport
var _out := "user://cards"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	for id: String in CARDS:
		var c: Array = CARDS[id]
		await _render(id, _window(c[0], c[1], c[2], c[3]))
	for s: String in STAGES:
		await _render("stage_" + s, _stage_tag(StageLibrary.stage_name(s)))
	await _render("legal", _legal())
	get_tree().quit()


## A blank full-screen page, already inside the viewport so windows can build.
func _fresh() -> Control:
	for ch in _vp.get_children():
		_vp.remove_child(ch)
		ch.queue_free()
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	_vp.add_child(root)
	return root


func _render(id: String, _node: Control) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, id])
	print("CARD ", id)


func _window(title: String, tab: String, lines: Array, anchor: String) -> Control:
	var root := _fresh()
	var w := PaperWindow.new()
	w.title = title
	w.tab_color = tab
	w.padding = Vector4(56, 44, 56, 34)
	root.add_child(w)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	w.content.add_child(box)
	for i in lines.size():
		var l := UIKit.label(lines[i], 3, UIKit.INK if i == 0 else UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(l)
	w.size = Vector2(440 if anchor == "left" else 1000, 10)
	w.fit_to_content()
	match anchor:
		"left": w.position = Vector2(24, (1080 - w.size.y) * 0.5 + 40)
		"low": w.position = Vector2((1920 - w.size.x) * 0.5, 1080 - w.size.y - 22)
		"bottom": w.position = Vector2((1920 - w.size.x) * 0.5, 1080 - w.size.y - 120)
		"center": w.position = (Vector2(1920, 1080) - w.size) * 0.5
		_: w.position = Vector2((1920 - w.size.x) * 0.5, 96)
	return root


func _stage_tag(name: String) -> Control:
	var root := _fresh()
	var w := PaperWindow.new()
	w.padding = Vector4(34, 18, 34, 14)
	root.add_child(w)
	var l := UIKit.label(name, 4, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	w.content.add_child(l)
	w.size = Vector2(300, 10)
	w.fit_to_content()
	# bottom left, clear of the board and the HUD
	w.position = Vector2(70, 1080 - w.size.y - 70)
	w.rotation = deg_to_rad(-2.0)
	return root


func _legal() -> Control:
	var root := _fresh()
	var l := UIKit.label(LEGAL, 2, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size = Vector2(1920, 40)
	l.position = Vector2(0, 22)       # top: the title screen has its own footer
	root.add_child(l)
	return root
