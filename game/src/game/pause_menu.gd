class_name PauseMenu
extends CanvasLayer
## Pause overlay: resume, restart, a few quick settings (and the Practice
## controls), quit. Pauses the tree and muffles the music while open.

signal resumed()
signal restart_requested()
signal quit_requested()
signal practice_changed()

const SHAKE := ["Off", "Light", "Full"]

var engine: TetrisEngine
var is_open := false

var _dim: ColorRect
var _win: PaperWindow
var _menu: ListMenu
var _hint: Label
var _confirm := ""
var _guard := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.07, 0.16, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_win = PaperWindow.new()
	_win.title = "PAUSE"
	_win.tab_color = "purple"
	_win.padding = Vector4(34, 44, 34, 30)
	add_child(_win)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_win.content.add_child(vb)
	_menu = ListMenu.new()
	_menu.min_width = 520
	_menu.value_width = 200
	_menu.wrap = true
	vb.add_child(_menu)
	_hint = UIKit.label("", 2, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_hint)
	_menu.activated.connect(_on_activated)
	_menu.value_step.connect(_on_value)
	_menu.cancelled.connect(_on_cancel)


func _items() -> Array:
	if _confirm != "":
		return [{"id": "yes", "text": "Yes"}, {"id": "no", "text": "No"}]
	var items: Array = [
		{"id": "resume", "text": "Resume"},
		{"id": "restart", "text": "Restart"},
	]
	if engine and engine.rules.mode == GameRules.Mode.PRACTICE:
		items.append({"id": "level", "text": "Level", "value": str(engine.level)})
		items.append({"id": "gravity", "text": "Gravity", "value": _on_off(engine.rules.gravity_enabled)})
	items.append({"id": "music", "text": "Music", "value": _pct("music_volume")})
	items.append({"id": "sfx", "text": "Sound FX", "value": _pct("sfx_volume")})
	items.append({"id": "ghost", "text": "Ghost Piece", "value": _on_off(Settings.get_value("ghost"))})
	items.append({"id": "shake", "text": "Screen Shake", "value": SHAKE[clampi(int(Settings.get_value("screen_shake")), 0, 2)]})
	items.append({"id": "quit", "text": "Quit to Menu"})
	return items


func _pct(key: String) -> String:
	return "%d%%" % int(round(float(Settings.get_value(key)) * 100.0))


func _on_off(v: Variant) -> String:
	return "On" if bool(v) else "Off"


func _rebuild(keep := true) -> void:
	_menu.set_items(_items(), keep)
	if _confirm == "restart":
		_win.title = "RESTART?"
		_hint.text = "This run will be lost."
	elif _confirm == "quit":
		_win.title = "QUIT?"
		_hint.text = "This run will be lost."
	else:
		_win.title = "PAUSE"
		_hint.text = _controls_hint()
	await get_tree().process_frame
	_win.fit_to_content()
	_win.position = (Vector2(1920, 1080) - _win.size) * 0.5


func _controls_hint() -> String:
	return tr("%s  move     %s  rotate     %s  drop") % [
		Controls.describe("game_left").split(" / ")[0] + "/" + Controls.describe("game_right").split(" / ")[0],
		Controls.describe("game_rotate_cw").split(" / ")[0],
		Controls.describe("game_hard_drop").split(" / ")[0],
	]


func open() -> void:
	if is_open:
		return
	is_open = true
	_confirm = ""
	visible = true
	_guard = 3
	get_tree().paused = true
	Audio.set_muffled(true)
	Audio.sfx("pause")
	Events.emit_event(&"pause")
	_menu.index = 0
	await _rebuild(false)
	_win.pop_in()
	_menu.set_active(true)
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.5, 0.2)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_menu.set_active(false)
	_win.pop_out()
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.0, 0.18)
	tw.tween_callback(func():
		if not is_open:
			visible = false)
	Audio.set_muffled(false)
	get_tree().paused = false
	Events.emit_event(&"resume")
	resumed.emit()


func _process(_delta: float) -> void:
	if _guard > 0:
		_guard -= 1


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or _guard > 0 or event.is_echo():
		return
	if event.is_action_pressed("game_pause") and not event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm == "":
			Audio.sfx("menu_back")
			close()


func _on_cancel() -> void:
	if _confirm != "":
		_confirm = ""
		_rebuild()
		return
	close()


func _on_activated(id: String) -> void:
	match id:
		"resume":
			close()
		"restart", "quit":
			_confirm = id
			_menu.index = 1
			_rebuild()
		"yes":
			var what := _confirm
			_confirm = ""
			is_open = false
			_menu.set_active(false)
			Audio.set_muffled(false)
			if what == "restart":
				restart_requested.emit()
			else:
				quit_requested.emit()
		"no":
			_confirm = ""
			_rebuild()


func _on_value(id: String, dir: int) -> void:
	match id:
		"music", "sfx":
			var key := "music_volume" if id == "music" else "sfx_volume"
			var v := clampf(snappedf(float(Settings.get_value(key)) + dir * 0.05, 0.05), 0.0, 1.0)
			Settings.set_value(key, v)
			_menu.set_value_text(id, _pct(key))
		"ghost":
			Settings.set_value("ghost", not bool(Settings.get_value("ghost")))
			_menu.set_value_text(id, _on_off(Settings.get_value("ghost")))
		"shake":
			Settings.set_value("screen_shake", wrapi(int(Settings.get_value("screen_shake")) + dir, 0, 3))
			_menu.set_value_text(id, SHAKE[int(Settings.get_value("screen_shake"))])
		"level":
			engine.level = clampi(engine.level + dir, 1, 20)
			_menu.set_value_text(id, str(engine.level))
			Settings.set_value("last_level", engine.level)
			practice_changed.emit()
		"gravity":
			engine.rules.gravity_enabled = not engine.rules.gravity_enabled
			Settings.set_value("practice_gravity", engine.rules.gravity_enabled)
			_menu.set_value_text(id, _on_off(engine.rules.gravity_enabled))
			practice_changed.emit()
