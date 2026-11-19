class_name ResultsScreen
extends CanvasLayer
## End-of-game window: main result with a counting tally, detailed stats,
## record placement and the Retry / Modes / Menu choices.

signal chosen(id: String)

var _dim: ColorRect
var _win: PaperWindow
var _menu: ListMenu
var _main_value: Label
var _record_badge: Control
var _info := {}


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_results(info: Dictionary) -> void:
	_info = info
	visible = true
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.07, 0.16, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	create_tween().tween_property(_dim, "color:a", 0.45, 0.3)

	var mode: int = info["mode"]
	var cleared: bool = info["cleared"]
	_win = PaperWindow.new()
	_win.title = _title(mode, cleared, str(info["reason"]))
	_win.tab_color = "gold" if cleared else "red"
	_win.padding = Vector4(44, 50, 44, 34)
	add_child(_win)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_win.content.add_child(vb)

	vb.add_child(UIKit.label(tr(GameRules.mode_name(mode)).to_upper(), 2, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var main_caption := "TIME" if mode == GameRules.Mode.SPRINT and cleared else "SCORE"
	vb.add_child(UIKit.label(main_caption, 3, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	_main_value = UIKit.label("0", 4, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_main_value.custom_minimum_size = Vector2(640, 80)
	vb.add_child(_main_value)

	_record_badge = _make_badge(int(info.get("rank", -1)), bool(info.get("records", true)))
	vb.add_child(_record_badge)

	vb.add_child(_separator())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	var st: Dictionary = info["stats"]
	var cells: Array = [
		["Score", UIKit.format_int(int(info["score"]))],
		["Time", UIKit.format_time(float(info["time"]))],
		["Lines", str(info["lines"])],
		["Level", str(info["level"])],
		["Pieces", str(info["pieces"])],
		["Pieces/s", "%.2f" % float(info["pps"])],
		["Tetris", str(st.get("tetrises", 0))],
		["T-Spins", str(int(st.get("tspins", 0)) + int(st.get("tspin_minis", 0)))],
		["Max Combo", str(maxi(int(st.get("max_combo", 0)), 0))],
		["B2B", str(st.get("b2b", 0))],
		["Perfect", str(st.get("perfect_clears", 0))],
		["Clears 1/2/3", "%d/%d/%d" % [st.get("singles", 0), st.get("doubles", 0), st.get("triples", 0)]],
	]
	for c: Array in cells:
		var k := UIKit.label(str(c[0]), 2, UIKit.INK_SOFT)
		var v := UIKit.label(str(c[1]), 2, UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		v.custom_minimum_size = Vector2(120, 0)
		grid.add_child(k)
		grid.add_child(v)
	vb.add_child(_separator())

	var center := CenterContainer.new()
	vb.add_child(center)
	_menu = ListMenu.new()
	_menu.min_width = 380
	_menu.active = false
	center.add_child(_menu)
	_menu.set_items([
		{"id": "retry", "text": "Retry"},
		{"id": "modes", "text": "Game Modes"},
		{"id": "menu", "text": "Main Menu"},
	], false)
	_menu.activated.connect(func(id: String): _choose(id))
	_menu.cancelled.connect(func(): _choose("menu"))

	await get_tree().process_frame
	_win.fit_to_content()
	_win.position = (Vector2(1920, 1080) - _win.size) * 0.5
	_win.pop_in()
	await get_tree().create_timer(0.35).timeout
	await _tally(mode, cleared)
	_menu.set_active(true)


func _title(mode: int, cleared: bool, reason: String) -> String:
	if mode == GameRules.Mode.ULTRA and reason == "time":
		return "TIME UP!"
	if cleared:
		return "CLEAR!"
	if mode == GameRules.Mode.ENDLESS or mode == GameRules.Mode.PRACTICE:
		return "RESULTS"
	return "GAME OVER"


func _separator() -> Control:
	var c := ColorRect.new()
	c.color = Color(UIKit.INK_SOFT, 0.35)
	c.custom_minimum_size = Vector2(0, 3)
	return c


func _make_badge(rank: int, records: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.custom_minimum_size = Vector2(0, 48)
	var text := ""
	var color := UIKit.INK_SOFT
	if not records:
		text = "Practice: no records"
	elif rank == 0:
		text = "NEW RECORD!"
		color = UIKit.RED
	elif rank > 0:
		text = tr("Rank #%d in Records") % (rank + 1)
		color = UIKit.BLUE
	else:
		var best: Dictionary = _info.get("best", {})
		if not best.is_empty():
			if int(_info["mode"]) == GameRules.Mode.SPRINT:
				text = tr("Best: %s") % UIKit.format_time(float(best.get("time", 0.0)))
			else:
				text = tr("Best: %s") % UIKit.format_int(int(best.get("score", 0)))
	if rank == 0:
		var star := SheetIcon.make(load("res://assets/sprites/ui/star_spin.png"), 8, 3, 12.0)
		hb.add_child(star)
	hb.add_child(UIKit.label(text, 3 if rank == 0 else 2, color))
	if rank == 0:
		var star2 := SheetIcon.make(load("res://assets/sprites/ui/star_spin.png"), 8, 3, 12.0)
		hb.add_child(star2)
	hb.modulate.a = 0.0
	return hb


func _tally(mode: int, cleared: bool) -> void:
	var is_time := mode == GameRules.Mode.SPRINT and cleared
	var target := float(_info["time"]) if is_time else float(_info["score"])
	var dur := clampf(0.4 + target / (60.0 if is_time else 40000.0), 0.4, 1.6)
	var t := 0.0
	var tick := 0.0
	while t < dur:
		var dt := get_process_delta_time()
		t += dt
		tick += dt
		var k := clampf(t / dur, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var v := target * k
		_main_value.text = UIKit.format_time(v) if is_time else UIKit.format_int(int(v))
		if tick > 0.06:
			tick = 0.0
			Audio.sfx("tally", 0.9 + k * 0.4)
		await get_tree().process_frame
	_main_value.text = UIKit.format_time(target) if is_time else UIKit.format_int(int(target))
	_main_value.pivot_offset = _main_value.size * 0.5
	var tw := create_tween()
	tw.tween_property(_main_value, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_main_value, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var rank := int(_info.get("rank", -1))
	_record_badge.pivot_offset = _record_badge.size * 0.5
	_record_badge.scale = Vector2(0.5, 0.5)
	var tb := create_tween().set_parallel(true)
	tb.tween_property(_record_badge, "modulate:a", 1.0, 0.15)
	tb.tween_property(_record_badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rank == 0:
		Audio.sfx("new_record")
		Events.emit_event(&"new_record", {"mode": mode})
	await get_tree().create_timer(0.3).timeout


func _choose(id: String) -> void:
	_menu.set_active(false)
	chosen.emit(id)
