class_name GameHud
extends Control
## Hold box, Next queue and the stats window around the well. Read-only view
## of the engine; numbers animate a little but always show the exact value
## once settled.

const COL_W := 250.0
const GAP := 34.0

const ICONS := {
	"coin": "res://assets/sprites/ui/coin_spin.png",
	"star": "res://assets/sprites/ui/item_star.png",
	"lines": "res://assets/sprites/ui/item_mushroom.png",
	"time": "res://assets/sprites/ui/item_stopwatch.png",
	"pieces": "res://assets/sprites/ui/block_blue.png",
	"best": "res://assets/sprites/ui/item_shooting_star.png",
	"left": "res://assets/sprites/ui/target.png",
}

var engine: TetrisEngine
var mode := 0
var best: Dictionary = {}

var hold_win: PaperWindow
var next_win: PaperWindow
var stats_win: PaperWindow
var hold_preview: PiecePreview
var next_previews: Array = []
var _values := {}      # row id -> Label
var _rows := {}        # row id -> Control
var _shown_score := 0.0
var _last_level := -1
var _time_warn := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## well_rect: the well in screen pixels.
func setup(e: TetrisEngine, well_rect: Rect2, best_entry: Dictionary) -> void:
	engine = e
	mode = e.rules.mode
	best = best_entry
	var left_x := well_rect.position.x - GAP - 22 - COL_W
	var right_x := well_rect.end.x + GAP + 22
	var top := well_rect.position.y + 6
	# --- hold
	hold_win = _window("HOLD", "blue", Vector2(left_x, top), Vector2(COL_W, 178))
	hold_preview = PiecePreview.new()
	hold_preview.cell = 40
	hold_preview.custom_minimum_size = Vector2(0, 100)
	hold_win.content.add_child(hold_preview)
	hold_win.visible = e.rules.hold_enabled
	# --- stats
	var stats_top := top + (220.0 if e.rules.hold_enabled else 0.0)
	stats_win = _window(_mode_title(), "red", Vector2(left_x, stats_top), Vector2(COL_W, 100))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	stats_win.content.add_child(vb)
	for r: Array in _row_defs():
		vb.add_child(_stat_row(r[0], r[1], r[2]))
	stats_win.fit_to_content()
	# --- next
	var n := e.rules.next_count
	next_win = _window("NEXT", "gold", Vector2(right_x, top), Vector2(COL_W, 100))
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 6)
	next_win.content.add_child(nb)
	for i in n:
		var p := PiecePreview.new()
		if i == 0:
			p.cell = 40
			p.custom_minimum_size = Vector2(0, 104)
		else:
			p.cell = 26
			p.small = true
			p.custom_minimum_size = Vector2(0, 70)
		nb.add_child(p)
		next_previews.append(p)
	next_win.fit_to_content()
	next_win.visible = n > 0
	refresh_queue()
	refresh_hold()
	_update_values(true)


func _mode_title() -> String:
	match mode:
		GameRules.Mode.SPRINT: return "SPRINT"
		GameRules.Mode.ULTRA: return "ULTRA"
		GameRules.Mode.ENDLESS: return "ENDLESS"
		GameRules.Mode.PRACTICE: return "PRACTICE"
	return "MARATHON"


## [id, label, icon]
func _row_defs() -> Array:
	match mode:
		GameRules.Mode.SPRINT:
			return [["left", "LINES LEFT", "left"], ["time", "TIME", "time"],
				["pieces", "PIECES", "pieces"], ["best", "BEST", "best"]]
		GameRules.Mode.ULTRA:
			return [["score", "SCORE", "coin"], ["time", "TIME LEFT", "time"],
				["lines", "LINES", "lines"], ["best", "BEST", "best"]]
		GameRules.Mode.PRACTICE:
			return [["level", "LEVEL", "star"], ["lines", "LINES", "lines"],
				["pieces", "PIECES", "pieces"], ["time", "TIME", "time"]]
	return [["score", "SCORE", "coin"], ["level", "LEVEL", "star"],
		["lines", "LINES", "lines"], ["time", "TIME", "time"]]


func _window(title: String, tab: String, pos: Vector2, sz: Vector2) -> PaperWindow:
	var w := PaperWindow.new()
	w.title = title
	w.tab_color = tab
	w.padding = Vector4(26, 34, 26, 22)
	add_child(w)
	w.position = pos
	w.size = sz
	return w


func _stat_row(id: String, text: String, icon_id: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var ic: Control
	if icon_id == "coin":
		ic = SheetIcon.make(load(ICONS["coin"]), 9, 1, 14.0, true)
	else:
		ic = UIKit.icon(load(ICONS[icon_id]), 1)
	ic.custom_minimum_size = Vector2(28, 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	top.add_child(UIKit.label(text, 2, UIKit.INK_SOFT))
	var small_value := id == "pieces" or id == "best"
	var v := UIKit.label("0", 2 if small_value else 3, UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(v)
	_values[id] = v
	_rows[id] = col
	return col


func refresh_queue() -> void:
	for i in next_previews.size():
		var p: PiecePreview = next_previews[i]
		p.type = engine.queue[i] if i < engine.queue.size() else 0


func refresh_hold() -> void:
	if hold_preview:
		hold_preview.type = engine.hold_type
		hold_preview.dimmed = engine.hold_locked


## Screen position of a stats value (where coins fly to), or ZERO.
func value_anchor(id: String) -> Vector2:
	if not _values.has(id) or not (_values[id] as Label).is_visible_in_tree():
		return Vector2.ZERO
	var l: Label = _values[id]
	return l.get_global_rect().get_center() + Vector2(l.size.x * 0.25, 0)


func bump(id: String) -> void:
	if not _values.has(id):
		return
	var l: Label = _values[id]
	l.pivot_offset = Vector2(l.size.x, l.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.18, 1.18), 0.07)
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	if engine == null:
		return
	_update_values(false, delta)
	if hold_preview and hold_preview.dimmed != engine.hold_locked:
		hold_preview.dimmed = engine.hold_locked


func _put(id: String, text: String, color := UIKit.INK) -> void:
	if not _values.has(id):
		return
	var l: Label = _values[id]
	if l.text != text:
		l.text = text
	l.add_theme_color_override("font_color", color)


func _update_values(snap: bool, delta := 0.0) -> void:
	var target := float(engine.score)
	if snap:
		_shown_score = target
	else:
		var diff := target - _shown_score
		_shown_score = target if absf(diff) < 1.0 else _shown_score + diff * minf(delta * 9.0, 1.0) + signf(diff)
		if (diff > 0 and _shown_score > target) or (diff < 0 and _shown_score < target):
			_shown_score = target
	_put("score", UIKit.format_int(int(round(_shown_score))))
	_put("level", str(engine.level))
	if engine.level != _last_level:
		if _last_level != -1:
			bump("level")
		_last_level = engine.level
	if engine.rules.line_goal > 0 and mode == GameRules.Mode.MARATHON:
		_put("lines", "%d/%d" % [engine.lines, engine.rules.line_goal])
	else:
		_put("lines", str(engine.lines))
	_put("left", str(maxi(engine.rules.line_goal - engine.lines, 0)))
	_put("pieces", "%d   %.2f/s" % [engine.pieces, engine.pieces_per_second()])
	if mode == GameRules.Mode.ULTRA:
		var tl := engine.time_left()
		var warn := tl <= 10.0 and engine.state != TetrisEngine.State.READY
		_put("time", UIKit.format_time(tl, true), UIKit.RED if warn else UIKit.INK)
	else:
		_put("time", UIKit.format_time(engine.time, mode == GameRules.Mode.SPRINT))
	if best.is_empty():
		_put("best", "---", UIKit.INK_SOFT)
	elif mode == GameRules.Mode.SPRINT:
		_put("best", UIKit.format_time(float(best.get("time", 0.0))), UIKit.INK_SOFT)
	else:
		_put("best", UIKit.format_int(int(best.get("score", 0))), UIKit.INK_SOFT)


## Panels slide in from the sides at the start.
func intro() -> void:
	var i := 0
	for w: PaperWindow in [hold_win, stats_win, next_win]:
		if w == null or not w.visible:
			continue
		var final := w.position
		var from_left := w.position.x < 960
		w.position.x += -420.0 if from_left else 420.0
		w.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(w, "position", final, 0.55).set_delay(0.12 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(w, "modulate:a", 1.0, 0.25).set_delay(0.12 * i)
		i += 1


## Little hop of a window (used for hold).
func hop(w: Control) -> void:
	if w == null:
		return
	var base := w.position.y
	var tw := create_tween()
	tw.tween_property(w, "position:y", base - 10.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "position:y", base, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Screen-space rects of the windows (Shy Guys may sit on top of them).
func platform_rects() -> Array:
	var out: Array = []
	var wins := [hold_win, stats_win, next_win].filter(func(w): return w and w.visible)
	for w: PaperWindow in wins:
		# a seat needs head room: skip a window tucked right under another
		var above := Rect2(w.position.x, w.position.y - 110.0, w.size.x, 110.0)
		var covered := false
		for o: PaperWindow in wins:
			if o != w and Rect2(o.position, o.size).intersects(above):
				covered = true
		if not covered:
			out.append(Rect2(w.position, w.size))
	return out
