extends Node2D
## Title screen and menu navigation (a stack of MenuPage windows) over the
## Toy Box diorama, with the Shy Guys hanging around.

const GAME_SCENE := "res://src/game/game.tscn"
const CREDITS_SCENE := "res://src/menu/credits.tscn"
const MENU_MUSIC := "menu_toybox"
const MainPage := preload("res://src/menu/pages/main_page.gd")

enum Phase { TITLE, MENU, LEAVING }

var phase: int = Phase.TITLE
var stage: StageView
var director: Director
var ui: CanvasLayer
var logo: Node2D
var _logo_paper: Sprite2D
const PAPER_Y := -50.0
var _press: Control
var _footer: Label
var _stack: Array = []
var _t := 0.0
var _title_guard := 0.4


func _ready() -> void:
	var params := Router.params
	stage = StageView.new()
	add_child(stage)
	stage.setup("toybox")
	director = Director.new()
	director.name = "Director"
	add_child(director)
	add_child(stage.front)
	director.setup("toybox", [Rect2(40, 930, 1840, 110)], [])

	var vig := Sprite2D.new()
	vig.texture = load("res://assets/ui/vignette.png")
	vig.centered = false
	vig.scale = Vector2(4, 4)
	vig.modulate.a = 0.55
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(vig)

	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	logo = Node2D.new()
	ui.add_child(logo)
	_logo_paper = Sprite2D.new()
	# one sheet: PAPER and TETRIS drawn on the same crumpled paper
	_logo_paper.texture = load("res://assets/ui/logo_paper.png")
	# the original Paper Mario sheet (MARIO painted out), TETRIS laid on it
	_logo_paper.position = Vector2(0, PAPER_Y)
	_logo_paper.scale = Vector2.ONE * 1.1
	_logo_paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.add_child(_logo_paper)

	# the prompt of the original title screen (French: its COMMENCER PARTIE)
	var prompt := TextureRect.new()
	prompt.texture = load("res://assets/sprites/ui/press_start_%s.png" % Lang.current())
	prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt.size = prompt.texture.get_size() * 4.0
	prompt.position = Vector2(960, 840) - prompt.size * 0.5
	prompt.pivot_offset = prompt.size * 0.5
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press = prompt
	ui.add_child(_press)
	_footer = UIKit.label("Unofficial fan game  -  free, not for sale", 2, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, true)
	_footer.size = Vector2(900, 40)
	_footer.position = Vector2(1920 - 930, 1030)
	ui.add_child(_footer)

	Audio.play_music(MENU_MUSIC, 1.0)
	if params.get("intro", false) or params.is_empty():
		_title_intro()
	else:
		_enter_menu(true)
		if str(params.get("open", "")) == "modes":
			await get_tree().create_timer(0.25).timeout
			push(preload("res://src/menu/pages/modes_page.gd").new())


# ------------------------------------------------------------------ title

func _title_intro() -> void:
	phase = Phase.TITLE
	logo.position = Vector2(960, 380)
	logo.scale = Vector2(0.2, 0.2)
	logo.modulate.a = 0.0
	_press.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.7).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, 0.3).set_delay(0.3)
	tw.tween_property(_press, "modulate:a", 1.0, 0.4).set_delay(1.1)
	get_tree().create_timer(0.35).timeout.connect(func(): Audio.sfx("stage_pop"))
	_title_guard = 0.9


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.TITLE or _title_guard > 0.0:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.is_echo():
		go = true
	elif event is InputEventJoypadButton and event.pressed:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventAction and event.pressed:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		Audio.sfx("menu_select")
		_enter_menu(false)


func _enter_menu(instant: bool) -> void:
	phase = Phase.MENU
	var tw := create_tween().set_parallel(true)
	var d := 0.0 if instant else 0.45
	tw.tween_property(logo, "position", Vector2(960, 250), d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "scale", Vector2(0.7, 0.7), d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, d)
	tw.tween_property(_press, "modulate:a", 0.0, minf(d, 0.2))
	var page := MainPage.new()
	if instant:
		push(page)
	else:
		get_tree().create_timer(0.25).timeout.connect(func(): push(page))


func _process(delta: float) -> void:
	_t += delta
	_title_guard -= delta
	if logo:
		_logo_paper.rotation = sin(_t * 1.3) * 0.012
		_logo_paper.position.y = PAPER_Y + sin(_t * 2.0) * 4.0
	if phase == Phase.TITLE and _press.modulate.a > 0.0:
		_press.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.03)
		_press.self_modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.2))


# ------------------------------------------------------------- navigation

func push(page: MenuPage) -> void:
	if phase == Phase.LEAVING:
		return
	if not _stack.is_empty():
		(_stack[-1] as MenuPage).close()
	page.nav = self
	ui.add_child(page)
	_stack.append(page)
	page.open()
	_update_logo()


func pop() -> void:
	if _stack.size() <= 1 or phase == Phase.LEAVING:
		return
	var p: MenuPage = _stack.pop_back()
	p.menu.set_active(false)
	p.pop_out(true)
	(_stack[-1] as MenuPage).open()
	_update_logo()


## The big logo only shows above the root menu; deeper windows get the room.
func _update_logo() -> void:
	var show := _stack.size() <= 1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 1.0 if show else 0.0, 0.25)
	tw.tween_property(logo, "position:y", 250.0 if show else 160.0, 0.3).set_trans(Tween.TRANS_QUAD)


func start_game(p: Dictionary) -> void:
	if phase == Phase.LEAVING:
		return
	phase = Phase.LEAVING
	for page: MenuPage in _stack:
		page.menu.set_active(false)
	Audio.sfx("go")
	Router.go(GAME_SCENE, p, "star")


func start_last() -> void:
	var mode_id := str(Settings.get_value("last_mode"))
	var m := GameRules.mode_from_id(mode_id)
	var lv := 1
	if m in [GameRules.Mode.MARATHON, GameRules.Mode.ENDLESS, GameRules.Mode.PRACTICE]:
		lv = int(Settings.get_value("last_level"))
	start_game({"mode": mode_id, "start_level": lv, "stage": str(Settings.get_value("last_stage"))})


func go_credits() -> void:
	if phase == Phase.LEAVING:
		return
	phase = Phase.LEAVING
	Router.go(CREDITS_SCENE, {}, "circle")


func quit_game() -> void:
	phase = Phase.LEAVING
	Audio.stop_music(0.6)
	var tw := create_tween()
	tw.tween_property(ui, "offset:y", 1200.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.7).timeout
	get_tree().quit()
