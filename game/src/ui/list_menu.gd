class_name ListMenu
extends VBoxContainer
## Old-school Paper Mario list menu with the white glove cursor.
## Keyboard, gamepad (with held-direction repeat) and mouse.
## Items: {id, text, value (optional, shows "< value >"), info (optional,
## right-aligned text that is not steppable), enabled}

signal activated(id: String)
signal value_step(id: String, dir: int)
signal moved(id: String)
signal cancelled()

@export var font_size := 3
@export var row_height := 62
@export var min_width := 360
@export var active := true
@export var wrap := true
@export var value_width := 220
@export var max_visible := 0     # > 0: scroll when there are more items

var items: Array = []
var index := 0

var _rows: Array = []
var _glove: TextureRect
var _bob := 0.0
var _hold_dir := 0
var _hold_t := 0.0
var _ready_frames := 2
var _scroll := 0
var _hhold_dir := 0
var _hhold_t := 0.0
## stick directions currently tilted past the deadzone (one step per tilt)
var _stick := {}
var _arrow_up: Label
var _arrow_down: Label
var _col_w := 0.0       # value column width: grows to the widest value seen
var _row_w := 0.0       # row width: grows so text + value always fit

const TEXT_X := 60.0
const GAP := 36.0


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_glove = UIKit.icon(UIKit.TEX_GLOVE, 3)
	_glove.top_level = false
	_glove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glove.z_index = 5
	add_child(_glove, false, Node.INTERNAL_MODE_BACK)
	_glove.set_as_top_level(false)
	_arrow_up = UIKit.label("↑", 2, UIKit.INK_SOFT)
	_arrow_down = UIKit.label("↓", 2, UIKit.INK_SOFT)
	for a: Label in [_arrow_up, _arrow_down]:
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.visible = false
		add_child(a, false, Node.INTERNAL_MODE_BACK)


## Replace all items. Keeps the selection if possible.
func set_items(new_items: Array, keep_index := true) -> void:
	items = new_items
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in items.size():
		var row := _make_row(i)
		add_child(row)
		_rows.append(row)
	if not keep_index:
		index = 0
	_col_w = 0.0
	_row_w = 0.0
	index = clampi(index, 0, maxi(items.size() - 1, 0))
	if not _is_enabled(index):
		_step(1, false)
	_refresh()


func _make_row(i: int) -> Control:
	var it: Dictionary = items[i]
	var row := Control.new()
	row.custom_minimum_size = Vector2(min_width, row_height)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := UIKit.label(str(it.get("text", "")), font_size, UIKit.INK)
	lbl.name = "Text"
	lbl.position = Vector2(TEXT_X, (row_height - UIKit.font_px(font_size)) * 0.5)
	row.add_child(lbl)
	if it.has("value") or it.has("info"):
		var val := UIKit.label("", font_size, UIKit.INK,
			HORIZONTAL_ALIGNMENT_CENTER if it.has("value") else HORIZONTAL_ALIGNMENT_RIGHT)
		val.name = "Value"
		val.custom_minimum_size = Vector2(value_width, 0)
		val.size = Vector2(value_width, UIKit.font_px(font_size))
		row.add_child(val)
	row.mouse_entered.connect(func():
		if active and _is_enabled(i) and index != i:
			index = i
			Audio.sfx("menu_move")
			_refresh()
			moved.emit(str(items[i].get("id", ""))))
	row.gui_input.connect(func(ev: InputEvent): _row_input(i, ev))
	return row


func _row_input(i: int, ev: InputEvent) -> void:
	if not active or not _is_enabled(i):
		return
	if ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		var it: Dictionary = items[i]
		if mb.button_index == MOUSE_BUTTON_LEFT:
			index = i
			if it.has("value"):
				var row: Control = _rows[i]
				var val: Label = row.get_node("Value")
				var dir := -1 if mb.position.x < val.position.x + val.size.x * 0.5 else 1
				_value(dir)
			else:
				_activate()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and it.has("value"):
			_value(1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and it.has("value"):
			_value(-1)
			accept_event()


func set_value_text(id: String, text: String) -> void:
	for i in items.size():
		if str(items[i].get("id", "")) == id:
			if items[i].has("info"):
				items[i]["info"] = text
			else:
				items[i]["value"] = text
	_refresh()


func set_item_text(id: String, text: String) -> void:
	for i in items.size():
		if str(items[i].get("id", "")) == id:
			items[i]["text"] = text
			(_rows[i].get_node("Text") as Label).text = text
	_refresh()


func current_id() -> String:
	if items.is_empty():
		return ""
	return str(items[index].get("id", ""))


func select_id(id: String) -> void:
	for i in items.size():
		if str(items[i].get("id", "")) == id:
			index = i
	_refresh()


func _is_enabled(i: int) -> bool:
	return i >= 0 and i < items.size() and items[i].get("enabled", true)


func _refresh() -> void:
	if max_visible > 0 and items.size() > max_visible:
		if index < _scroll:
			_scroll = index
		elif index >= _scroll + max_visible:
			_scroll = index - max_visible + 1
		_scroll = clampi(_scroll, 0, items.size() - max_visible)
	else:
		_scroll = 0
	for i in _rows.size():
		var shown := max_visible <= 0 or (i >= _scroll and i < _scroll + max_visible)
		(_rows[i] as Control).visible = shown
	for i in _rows.size():
		var row: Control = _rows[i]
		var it: Dictionary = items[i]
		var lbl: Label = row.get_node("Text")
		var col := UIKit.INK
		if not _is_enabled(i):
			col = UIKit.DISABLED
		elif i == index and active:
			col = UIKit.SELECT
		lbl.add_theme_color_override("font_color", col)
		if it.has("value"):
			var val: Label = row.get_node("Value")
			var arrows := i == index and active
			val.text = ("<  %s  >" % tr(str(it["value"]))) if arrows else str(it["value"])
			val.add_theme_color_override("font_color", col if i == index and active else UIKit.INK_SOFT)
		elif it.has("info"):
			(row.get_node("Value") as Label).text = str(it["info"])
	_layout_rows()
	_place_glove(true)


## Measures every text and value (the selected one with its arrows) and
## sizes the value column and the rows so nothing runs out of the paper.
func _layout_rows() -> void:
	var col := float(value_width)
	var text_w := 0.0
	for i in _rows.size():
		var row: Control = _rows[i]
		var it: Dictionary = items[i]
		text_w = maxf(text_w, _text_width(row.get_node("Text") as Label, str(it.get("text", ""))))
		if it.has("value"):
			# reserve room for the arrows even when the row is not selected
			col = maxf(col, _text_width(row.get_node("Value") as Label, "<  %s  >" % tr(str(it["value"]))) + 8.0)
		elif it.has("info"):
			col = maxf(col, _text_width(row.get_node("Value") as Label, str(it["info"])) + 8.0)
	_col_w = maxf(_col_w, ceilf(col))
	var has_col := _col_w > 0.0 and items.any(func(x): return x.has("value") or x.has("info"))
	var need := TEXT_X + text_w + (GAP + _col_w if has_col else 24.0)
	_row_w = maxf(_row_w, maxf(float(min_width), ceilf(need)))
	for i in _rows.size():
		var row: Control = _rows[i]
		row.custom_minimum_size.x = _row_w
		if row.has_node("Value"):
			var val: Label = row.get_node("Value")
			val.custom_minimum_size.x = _col_w
			val.size = Vector2(_col_w, UIKit.font_px(font_size))
			val.position = Vector2(_row_w - _col_w, (row.get_node("Text") as Label).position.y)


func _text_width(l: Label, text: String) -> float:
	var f := l.get_theme_font("font")
	if f == null or text == "":
		return 0.0
	return f.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


func _notification(what: int) -> void:
	# another language: texts change length, measure everything again
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _rows.is_empty():
		_col_w = 0.0
		_row_w = 0.0
		_refresh.call_deferred()


func _place_arrows() -> void:
	if _arrow_up == null:
		return
	var scrolling := max_visible > 0 and items.size() > max_visible
	_arrow_up.visible = scrolling and _scroll > 0
	_arrow_down.visible = scrolling and _scroll + max_visible < items.size()
	_arrow_up.position = Vector2(14, -30)
	_arrow_down.position = Vector2(14, max_visible * row_height - 4)


func _place_glove(_snap := false) -> void:
	if _glove == null or _rows.is_empty():
		return
	_glove.visible = active
	var row: Control = _rows[index]
	var target := row.position + Vector2(4, (row_height - _glove.custom_minimum_size.y) * 0.5)
	_glove.size = _glove.custom_minimum_size
	_glove.position = target + Vector2(sin(_bob) * 5.0 - 3.0, 0)


func _process(delta: float) -> void:
	_bob += delta * 7.0
	_place_glove()
	if _ready_frames > 0:
		_ready_frames -= 1
	if not active or not is_visible_in_tree():
		_hold_dir = 0
		return
	# gamepad stick / d-pad repeat for vertical navigation
	var dir := 0
	if Input.is_action_pressed("ui_down"):
		dir = 1
	elif Input.is_action_pressed("ui_up"):
		dir = -1
	if dir != 0 and dir == _hold_dir:
		_hold_t += delta
		if _hold_t > 0.4:
			_hold_t -= 0.13
			_step(dir)
	else:
		_hold_dir = dir
		_hold_t = 0.0
	# held left / right on a value row keeps stepping
	var h := 0
	if items.size() > 0 and items[index].has("value"):
		if Input.is_action_pressed("ui_right"):
			h = 1
		elif Input.is_action_pressed("ui_left"):
			h = -1
	if h != 0 and h == _hhold_dir:
		_hhold_t += delta
		if _hhold_t > 0.42:
			_hhold_t -= 0.11
			_value(h)
	else:
		_hhold_dir = h
		_hhold_t = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or items.is_empty() or _ready_frames > 0:
		return
	if event.is_echo():
		return
	# an analog stick sends a stream of motion events while tilted: only the
	# tilt itself moves the cursor, holding it repeats from _process
	if event is InputEventJoypadMotion:
		var fresh := false
		for a: String in ["ui_down", "ui_up", "ui_left", "ui_right"]:
			if event.is_action(a):
				var on := event.is_action_pressed(a)
				if on and not _stick.get(a, false):
					fresh = true
				_stick[a] = on
		if not fresh:
			return
	if event.is_action_pressed("ui_down"):
		_step(1)
	elif event.is_action_pressed("ui_up"):
		_step(-1)
	elif event.is_action_pressed("ui_left"):
		if items[index].has("value"):
			_value(-1)
	elif event.is_action_pressed("ui_right"):
		if items[index].has("value"):
			_value(1)
	elif event.is_action_pressed("ui_accept"):
		if items[index].has("value"):
			_value(1)
		else:
			_activate()
	elif event.is_action_pressed("ui_cancel"):
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _step(dir: int, sound := true) -> void:
	if items.is_empty():
		return
	var i := index
	for k in items.size():
		i += dir
		if i < 0 or i >= items.size():
			if not wrap:
				return
			i = posmod(i, items.size())
		if _is_enabled(i):
			break
	if i == index:
		return
	index = i
	if sound:
		Audio.sfx("menu_move")
	_refresh()
	_pop_row(index)
	moved.emit(current_id())


func _pop_row(i: int) -> void:
	var lbl: Label = _rows[i].get_node("Text")
	var tw := create_tween()
	lbl.pivot_offset = lbl.size * Vector2(0, 0.5)
	tw.tween_property(lbl, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _value(dir: int) -> void:
	Audio.sfx("menu_tick")
	value_step.emit(current_id(), dir)


func _activate() -> void:
	Audio.sfx("menu_select")
	_pop_row(index)
	Events.emit_event(&"menu_select")
	activated.emit(current_id())


func _cancel() -> void:
	Audio.sfx("menu_back")
	Events.emit_event(&"menu_back")
	cancelled.emit()


func set_active(on: bool) -> void:
	active = on
	_ready_frames = 2
	_refresh()
