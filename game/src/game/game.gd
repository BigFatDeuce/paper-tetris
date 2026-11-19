extends Node2D
## Gameplay scene. Owns one TetrisEngine and wires it to input, views,
## audio and the decorative world. The decor only ever receives events.

const GAME_SCENE := "res://src/game/game.tscn"
const MENU_SCENE := "res://src/menu/main_menu.tscn"

const WELL_POS := Vector2(740, 146)
const ACTIONS := ["game_left", "game_right", "game_soft_drop", "game_hard_drop",
	"game_rotate_cw", "game_rotate_ccw", "game_hold", "game_pause"]

enum Phase { INTRO, COUNTDOWN, PLAY, ENDING, RESULTS }

var params := {}
var mode := 0
var rules: GameRules
var engine: TetrisEngine
var phase: int = Phase.INTRO
var stage_auto := true
var stage_id := "toybox"

var camera: Camera2D
var stage: StageView
var director: Director
var board: BoardView
var hud: GameHud
var callouts: Callouts
var pause_menu: PauseMenu
var results: ResultsScreen

var _auto := AutoRepeat.new()
var _held := {}
var _hard_dropped := false
var _shake := 0.0
var _shake_t := 0.0
var _best_before := {}
var _last_ultra_tick := -1


func _ready() -> void:
	params = Router.params.duplicate()
	mode = GameRules.mode_from_id(str(params.get("mode", Settings.get_value("last_mode"))))
	var opts := {
		"start_level": int(params.get("start_level", 1)),
		"level_up": bool(params.get("level_up", Settings.get_value("practice_level_up"))),
		"gravity": bool(params.get("gravity", Settings.get_value("practice_gravity"))),
		"hold": bool(Settings.get_value("hold")),
	}
	if params.has("seed"):
		opts["seed"] = int(params["seed"])
	rules = GameRules.for_mode(mode, opts)
	rules.next_count = clampi(int(Settings.get_value("next_count")), 0, 5)
	rules.soft_drop_factor = maxf(float(Settings.get_value("soft_drop_factor")), 2.0)
	engine = TetrisEngine.new(rules)
	_auto.das = float(Settings.get_value("das"))
	_auto.arr = float(Settings.get_value("arr"))
	_best_before = SaveData.best(GameRules.mode_id(mode)).duplicate()
	for a: String in ACTIONS:
		_held[a] = Input.is_action_pressed(a)

	var chosen := str(params.get("stage", "auto"))
	stage_auto = chosen == "auto" or not StageLibrary.STAGES.has(chosen)
	if stage_auto:
		if mode == GameRules.Mode.MARATHON or mode == GameRules.Mode.ENDLESS:
			stage_id = StageLibrary.for_level(engine.level)
		else:
			stage_id = StageLibrary.default_for_mode(mode)
	else:
		stage_id = chosen
	_build()
	_connect_engine()
	Settings.changed.connect(_on_setting)
	Audio.play_playlist(_playlist_for(stage_id), 0.8)
	Events.emit_event(&"stage", {"id": stage_id})
	_run_intro()


func _build() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	camera.make_current()

	stage = StageView.new()
	add_child(stage)
	stage.setup(stage_id)

	director = Director.new()
	director.name = "Director"
	add_child(director)
	add_child(stage.front)

	var board_root := Node2D.new()
	board_root.name = "BoardRoot"
	add_child(board_root)
	var well := Vector2(TetrisEngine.WIDTH, TetrisEngine.VISIBLE) * BoardView.CELL
	var frame := NinePatchRect.new()
	frame.texture = load("res://assets/ui/board_frame.png")
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(m, 36)
	frame.position = WELL_POS - Vector2(22, 22)
	frame.size = well + Vector2(44, 44)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_root.add_child(frame)
	var frame_shadow := NinePatchRect.new()
	frame_shadow.texture = UIKit.TEX_SHADOW
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame_shadow.set_patch_margin(m, 56)
	frame_shadow.position = frame.position + Vector2(12, 14) - Vector2(28, 28)
	frame_shadow.size = frame.size + Vector2(56, 56)
	frame_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_root.add_child(frame_shadow)
	board_root.move_child(frame_shadow, 0)

	board = BoardView.new()
	board.position = WELL_POS
	board_root.add_child(board)
	board.bind(engine)
	board.ghost_enabled = bool(Settings.get_value("ghost"))
	board.grid_enabled = bool(Settings.get_value("grid"))
	var shade := NinePatchRect.new()
	shade.texture = load("res://assets/ui/well_shade.png")
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		shade.set_patch_margin(m, 40)
	shade.position = WELL_POS
	shade.size = well
	shade.modulate.a = 0.55
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_root.add_child(shade)

	hud = GameHud.new()
	add_child(hud)
	hud.setup(engine, Rect2(WELL_POS, well), _best_before)

	callouts = Callouts.new()
	add_child(callouts)
	callouts.setup(board)

	# decor zones: the ground on both sides of the board + window tops
	var zones := [Rect2(40, 930, 380, 110), Rect2(1500, 930, 380, 110)]
	director.setup(stage_id, zones, hud.platform_rects())
	director.hide_rect = Rect2(WELL_POS - Vector2(22, 22), well + Vector2(44, 44))

	add_child(TouchControls.new())
	pause_menu = PauseMenu.new()
	pause_menu.engine = engine
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.quit_requested.connect(func(): _leave({}))
	pause_menu.resumed.connect(_on_resumed)
	pause_menu.practice_changed.connect(func(): hud.bump("level"))

	results = ResultsScreen.new()
	add_child(results)
	results.chosen.connect(_on_result_choice)


func _connect_engine() -> void:
	engine.piece_moved.connect(func(_dx): Audio.sfx("move"))
	engine.piece_rotated.connect(func(_dir, kick):
		Audio.sfx("rotate", 1.0 if kick == 0 else 1.06)
		board.bounce_piece())
	engine.piece_landed.connect(func(): Audio.sfx("soft_drop", 1.0, -6.0))
	engine.hard_dropped.connect(_on_hard_drop)
	engine.piece_locked.connect(_on_locked)
	engine.lines_cleared.connect(_on_lines)
	engine.level_changed.connect(_on_level)
	engine.hold_used.connect(func(t):
		Audio.sfx("hold")
		hud.refresh_hold()
		hud.hop(hud.hold_win)
		Events.emit_event(&"hold", {"type": t}))
	engine.queue_changed.connect(func(): hud.refresh_queue())
	engine.piece_spawned.connect(func(_t): hud.refresh_hold())
	engine.danger_changed.connect(func(on):
		if on and phase == Phase.PLAY:
			Audio.sfx("danger")
		Events.emit_event(&"danger", {"on": on}))
	engine.finished.connect(_on_finished)


func _music_for(id: String) -> String:
	var choice := str(Settings.get_value("music_choice"))
	if choice != "stage" and choice != "auto" and Audio.music_catalog.has(choice):
		return choice
	match mode:
		GameRules.Mode.SPRINT: return "mode_sprint"
		GameRules.Mode.ULTRA: return "mode_ultra"
	return str(StageLibrary.get_stage(id)["music"])


## The stage's two themes, played one after the other (a chosen track alone).
func _playlist_for(id: String) -> Array:
	var first := _music_for(id)
	var st: Dictionary = StageLibrary.get_stage(id)
	if first == str(st["music"]) and st.has("music2"):
		return [first, str(st["music2"])]
	return [first]


# ------------------------------------------------------------------ flow

func _run_intro() -> void:
	phase = Phase.INTRO
	hud.intro()
	await get_tree().create_timer(0.75, false).timeout
	phase = Phase.COUNTDOWN
	await callouts.countdown()
	if phase != Phase.COUNTDOWN:
		return
	phase = Phase.PLAY
	engine.begin()
	Events.emit_event(&"game_start", {"mode": GameRules.mode_id(mode)})


func _restart() -> void:
	Router.go(GAME_SCENE, params, "circle")


func _leave(p: Dictionary) -> void:
	Audio.stop_music(0.5)
	Router.go(MENU_SCENE, p, "star")


func _on_result_choice(id: String) -> void:
	match id:
		"retry": _restart()
		"modes": _leave({"open": "modes"})
		_: _leave({})


func _on_finished(reason: String) -> void:
	phase = Phase.ENDING
	_auto.reset()
	var cleared := engine.is_clear()
	var mid := GameRules.mode_id(mode)
	if reason == "topout":
		Audio.stop_music(0.25)
		Audio.sfx("game_over")
		board.start_topout()
		shake(14.0)
		callouts.banner("GAME OVER", UIKit.RED, -1.0, -60.0)
		Events.emit_event(&"game_over", {"mode": mid, "score": engine.score})
	else:
		Audio.stop_music(0.3)
		Audio.sfx("victory")
		var text := "TIME UP!" if reason == "time" else "CLEAR!"
		callouts.banner(text, UIKit.GOLD, -1.0, -60.0)
		if Settings.get_value("particles"):
			for i in 5:
				get_tree().create_timer(0.15 * i, false).timeout.connect(func():
					callouts.confetti(Vector2(randf_range(780, 1140), randf_range(380, 700)), 30, Vector2(40, 10), 600.0))
		Events.emit_event(&"game_clear", {"mode": mid, "score": engine.score})
	await get_tree().create_timer(2.6, false).timeout
	_show_results(reason, cleared)


func _show_results(reason: String, cleared: bool) -> void:
	phase = Phase.RESULTS
	var mid := GameRules.mode_id(mode)
	var rank := -1
	var counts := rules.save_records and (mode != GameRules.Mode.SPRINT or reason == "goal")
	if counts:
		rank = SaveData.submit(mid, {
			"score": engine.score, "lines": engine.lines, "level": engine.level,
			"time": snappedf(engine.time, 0.001), "pieces": engine.pieces,
			"pps": snappedf(engine.pieces_per_second(), 0.01),
			"tetrises": engine.stats["tetrises"], "start_level": rules.start_level,
			"cleared": cleared,
		})
	SaveData.add_lifetime({"lines": engine.lines, "tetrises": engine.stats["tetrises"],
		"pieces": engine.pieces, "time": engine.time})
	Audio.play_music("results_clear" if cleared or reason != "topout" else "results_over", 0.6)
	results.show_results({
		"mode": mode, "cleared": cleared, "reason": reason,
		"score": engine.score, "lines": engine.lines, "level": engine.level,
		"time": engine.time, "pieces": engine.pieces, "pps": engine.pieces_per_second(),
		"stats": engine.stats, "rank": rank, "records": rules.save_records,
		"best": _best_before,
	})


# ----------------------------------------------------------------- engine

func _on_hard_drop(rows: int, cells: Array) -> void:
	_hard_dropped = true
	Audio.sfx("hard_drop", 1.0 + clampf(rows / 40.0, 0.0, 0.2))
	callouts.dust(cells)
	shake(2.0 + minf(rows * 0.25, 4.0))
	Events.emit_event(&"hard_drop", {"rows": rows, "x": _cells_x(cells)})


func _on_locked(cells: Array, type: int, _tspin: int) -> void:
	if not _hard_dropped:
		Audio.sfx("lock")
	_hard_dropped = false
	Events.emit_event(&"lock", {"type": type, "x": _cells_x(cells)})


func _cells_x(cells: Array) -> float:
	if cells.is_empty():
		return 960.0
	var sx := 0.0
	for c: Vector2i in cells:
		sx += c.x
	return WELL_POS.x + (sx / cells.size() + 0.5) * BoardView.CELL


func _on_lines(rows: Array, res: Dictionary) -> void:
	var n: int = res["lines"]
	var tspin: int = res["tspin"]
	if res.get("perfect", false):
		Audio.sfx("perfect")
	if tspin != TetrisEngine.TSpin.NONE:
		Audio.sfx("tspin")
	elif n > 0:
		Audio.sfx("clear%d" % mini(n, 4))
	if res.get("b2b", false):
		Audio.sfx("b2b")
	var combo := int(res.get("combo", -1))
	if combo > 0:
		Audio.sfx("combo", 1.0 + 0.06 * mini(combo, 12))
	callouts.clear_callout(res, rows)
	if n > 0 and not rows.is_empty():
		var target := hud.value_anchor("score")
		if target == Vector2.ZERO:
			target = hud.value_anchor("lines")
		var row_y := WELL_POS.y + board.cell_pos(Vector2i(0, int(rows[0]))).y + BoardView.CELL * 0.5
		var coins: int = [0, 2, 4, 6, 10][mini(n, 4)] + (6 if res.get("perfect", false) else 0)
		callouts.coin_shower(Vector2(WELL_POS.x + board.well_size().x * 0.5, row_y), target, coins,
			func(): hud.bump("score"))
	if n >= 4 or res.get("perfect", false):
		shake(10.0 if not res.get("perfect", false) else 14.0)
	elif n > 0:
		shake(2.0 + n)
	if n > 0:
		hud.bump("lines")
		hud.bump("left")
	var data := res.duplicate()
	data["rows"] = rows
	Events.emit_event(&"lines", data)
	if n == 4:
		Events.emit_event(&"tetris", data)
	if tspin != TetrisEngine.TSpin.NONE and n > 0:
		Events.emit_event(&"tspin", data)
	if combo >= 2:
		Events.emit_event(&"combo", data)
	if res.get("perfect", false):
		Events.emit_event(&"perfect", data)


func _on_level(level: int) -> void:
	if phase != Phase.PLAY:
		return
	Audio.sfx("level_up")
	callouts.level_up(level)
	Events.emit_event(&"level_up", {"level": level})
	if stage_auto and (mode == GameRules.Mode.MARATHON or mode == GameRules.Mode.ENDLESS):
		var next := StageLibrary.for_level(level)
		if next != stage_id:
			stage_id = next
			stage.change_to(next)
			director.change_stage(next)
			Audio.play_playlist(_playlist_for(next), 1.6)
			Events.emit_event(&"stage", {"id": next})


func _on_setting(key: String) -> void:
	match key:
		"ghost": board.ghost_enabled = bool(Settings.get_value("ghost"))
		"grid": board.grid_enabled = bool(Settings.get_value("grid"))


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if _poll_actions():
			get_viewport().set_input_as_handled()


## Turns action state changes into presses / releases. Returns true if a
## game action changed.
func _poll_actions() -> bool:
	var any := false
	for a: String in ACTIONS:
		var p := Input.is_action_pressed(a)
		if p != _held[a]:
			_held[a] = p
			any = true
			if p:
				_on_press(a)
			else:
				_on_release(a)
	return any


func _on_press(a: String) -> void:
	if a == "game_pause":
		if phase == Phase.PLAY or phase == Phase.COUNTDOWN or phase == Phase.INTRO:
			pause_menu.open()
		return
	match a:
		"game_left":
			_auto.press(-1)
			if phase == Phase.PLAY:
				_move(-1, 1)
		"game_right":
			_auto.press(1)
			if phase == Phase.PLAY:
				_move(1, 1)
	if phase != Phase.PLAY:
		return
	match a:
		"game_hard_drop":
			engine.hard_drop()
		"game_rotate_cw":
			if not engine.rotate(1) and engine.state == TetrisEngine.State.FALLING:
				Audio.sfx("rotate_fail")
		"game_rotate_ccw":
			if not engine.rotate(-1) and engine.state == TetrisEngine.State.FALLING:
				Audio.sfx("rotate_fail")
		"game_hold":
			if engine.state == TetrisEngine.State.FALLING and not engine.hold() and rules.hold_enabled:
				Audio.sfx("menu_deny")


func _on_release(a: String) -> void:
	match a:
		"game_left": _auto.release(-1)
		"game_right": _auto.release(1)


func _move(dir: int, n: int) -> void:
	for i in mini(n, TetrisEngine.WIDTH):
		if not engine.move(dir):
			break


func _on_resumed() -> void:
	# keys pressed or released while paused must not act on resume
	for a: String in ACTIONS:
		_held[a] = Input.is_action_pressed(a)
	_auto.reset()
	if _held["game_left"]:
		_auto.press(-1)
	if _held["game_right"]:
		_auto.press(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == Phase.PLAY and not DisplayServer.get_name() == "headless":
		pause_menu.open()


# ---------------------------------------------------------------- process

func _process(delta: float) -> void:
	_poll_actions()
	var dt := minf(delta, 0.1)
	match phase:
		Phase.PLAY:
			var moves := _auto.update(dt)
			if moves > 0 and _auto.direction() != 0:
				_move(_auto.direction(), moves)
			engine.set_soft_drop(_held["game_soft_drop"])
			engine.update(dt)
			_ultra_ticks()
		Phase.COUNTDOWN, Phase.INTRO:
			_auto.update(dt)
	_update_shake(delta)


func _ultra_ticks() -> void:
	if mode != GameRules.Mode.ULTRA or phase != Phase.PLAY:
		return
	var left := int(ceil(engine.time_left()))
	if left <= 10 and left != _last_ultra_tick and left > 0:
		_last_ultra_tick = left
		Audio.sfx("count", 1.0 + (10 - left) * 0.03)


func shake(amount: float) -> void:
	var level := int(Settings.get_value("screen_shake"))
	if level <= 0:
		return
	_shake = maxf(_shake, amount * (0.45 if level == 1 else 1.0))


func _update_shake(delta: float) -> void:
	if _shake <= 0.05:
		camera.offset = Vector2.ZERO
		_shake = 0.0
		return
	_shake_t += delta
	camera.offset = Vector2(sin(_shake_t * 73.0), cos(_shake_t * 61.0)) * _shake
	_shake = move_toward(_shake, 0.0, delta * (14.0 + _shake * 6.0))
