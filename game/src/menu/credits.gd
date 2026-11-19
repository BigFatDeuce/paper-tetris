extends Node2D
## Credits: a paper scroll rolling over the Shooting Star Summit while the
## Shy Guys parade below. Any button speeds it up, Cancel leaves.

const MENU_SCENE := "res://src/menu/main_menu.tscn"

const LINES := [
	["logo", ""],
	["gap", ""],
	["small", "An unofficial fan game, made for fun."],
	["small", "Free and non-commercial. Not affiliated with Nintendo."],
	["gap", ""],
	["head", "GAME"],
	["text", "Produced by"],
	["small", "BigFatDeuce"],
	["text", "Design, programming, paper crafts"],
	["small", "Claude (Anthropic)"],
	["text", "Engine"],
	["small", "Godot Engine 4.7  -  godotengine.org"],
	["gap", ""],
	["head", "ORIGINAL WORKS"],
	["text", "Tetris"],
	["small", "Alexey Pajitnov (1984)  -  The Tetris Company"],
	["text", "Paper Mario"],
	["small", "Intelligent Systems / Nintendo (2000)"],
	["text", "Shy Guys and friends"],
	["small", "Nintendo"],
	["gap", ""],
	["head", "MUSIC"],
	["text", "Paper Mario original soundtrack"],
	["small", "Yuka Tsujiyoko and Taishi Senda"],
	["small", "Looped and mixed for this game"],
	["gap", ""],
	["head", "SPRITES"],
	["text", "Rips from The Spriters Resource"],
	["small", "Retriever II, Kimimaru, Oddball XP, Jackster"],
	["gap", ""],
	["head", "STAGES"],
	["text", "Paper Mario battle backgrounds"],
	["small", "Intelligent Systems / Nintendo"],
	["text", "Battle stage, area models, textures"],
	["small", "The Models Resource  -  MasterGamePro, Alec Pike"],
	["small", "Rendered and dressed in 3D for this game"],
	["gap", ""],
	["head", "SOUNDS"],
	["text", "Paper Mario sound samples"],
	["small", "Instruments and effects"],
	["small", "The Sounds Resource  -  aldelaro5"],
	["small", "Jingles and effects composed with them"],
	["gap", ""],
	["head", "STARRING"],
	["text", "The Shy Guy Toy Box Troupe"],
	["small", "Red, Blue, Green, Pink, Yellow and Anti Guy"],
	["small", "Groove Guy, Sky Guy, Spy Guy, Stilt Guy"],
	["small", "Pyro Guy, Spear Guy, Traffic Guy, General Guy"],
	["gap", ""],
	["gap", ""],
	["head", "LEGAL"],
	["small", "Paper Mario, Shy Guy and all related characters, music, sounds and graphics belong to Nintendo and Intelligent Systems. Tetris is a trademark of The Tetris Company. This fan project is not endorsed by them."],
	["gap", ""],
	["gap", ""],
	["head", "THANK YOU FOR PLAYING!"],
	["gap", ""],
]

var _scroll: Control
var _speed := 70.0
var _done := false
var _t := 0.0


func _ready() -> void:
	var stage := StageView.new()
	add_child(stage)
	stage.setup("stars")
	var director := Director.new()
	add_child(director)
	add_child(stage.front)
	director.setup("stars", [Rect2(40, 930, 1840, 110)], [])
	if director.has_method("parade"):
		director.call("parade")
	Audio.play_music("credits", 1.0)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var win := PaperWindow.new()
	win.style = "light"
	win.position = Vector2(560, 40)
	win.size = Vector2(800, 860)
	ui.add_child(win)
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(30, 30)
	clip.size = Vector2(740, 800)
	win.add_child(clip)
	_scroll = VBoxContainer.new()
	_scroll.add_theme_constant_override("separation", 8)
	_scroll.size = Vector2(740, 10)
	_scroll.position = Vector2(0, 260)
	clip.add_child(_scroll)
	for l: Array in LINES:
		match l[0]:
			"logo":
				# the title logo: TETRIS laid over the crumpled PAPER sheet
				var box := Control.new()
				box.custom_minimum_size = Vector2(740, 360)
				var paper := TextureRect.new()
				paper.texture = load("res://assets/ui/logo_paper.png")
				paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				paper.size = Vector2(608, 352)
				paper.position = Vector2((740 - 608) * 0.5, 4)
				box.add_child(paper)
				var tet := TextureRect.new()
				tet.texture = load("res://assets/ui/logo_tetris.png")
				tet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tet.size = Vector2(518, 113)
				tet.position = Vector2((740 - 518) * 0.5, 4 + 352 * 0.70 - 56)
				box.add_child(tet)
				_scroll.add_child(box)
			"gap":
				var c := Control.new()
				c.custom_minimum_size = Vector2(0, 40)
				_scroll.add_child(c)
			"head":
				_scroll.add_child(_line(l[1], 3, UIKit.RED))
			"text":
				_scroll.add_child(_line(l[1], 3, UIKit.INK))
			"small":
				_scroll.add_child(_line(l[1], 2, UIKit.INK_SOFT))
	var hint := UIKit.label("Hold Confirm: faster     Cancel: back", 2, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	hint.size = Vector2(1920, 40)
	hint.position = Vector2(0, 1020)
	ui.add_child(hint)
	win.pop_in(0.2)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var fast := Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_scroll.position.y -= delta * _speed * (4.0 if fast else 1.0)
	var end := -_scroll.size.y + 380.0
	if _scroll.position.y < end:
		_scroll.position.y = end
		if _t > 3.0:
			_done = true
			await get_tree().create_timer(4.0).timeout
			_leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_pause"):
		get_viewport().set_input_as_handled()
		Audio.sfx("menu_back")
		_leave()


func _leave() -> void:
	if Router.busy:
		return
	_done = true
	Router.go(MENU_SCENE, {}, "circle")


## A centred credits line that wraps instead of running out of the page.
func _line(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	return l
