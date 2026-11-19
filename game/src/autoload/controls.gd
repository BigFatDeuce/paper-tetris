extends Node
## Input map: creates the game actions with default keyboard / gamepad
## bindings, applies user rebinds stored in Settings, and tracks which
## device was used last (to show the right button hints).

signal device_changed(is_pad: bool)
signal bindings_changed()
signal touch_changed()

const GAME_ACTIONS := [
	"game_left", "game_right", "game_soft_drop", "game_hard_drop",
	"game_rotate_cw", "game_rotate_ccw", "game_hold", "game_pause",
]
const ACTION_LABELS := {
	"game_left": "Move Left", "game_right": "Move Right",
	"game_soft_drop": "Soft Drop", "game_hard_drop": "Hard Drop",
	"game_rotate_cw": "Rotate Right", "game_rotate_ccw": "Rotate Left",
	"game_hold": "Hold", "game_pause": "Pause",
}

## Keyboard defaults (physical keycodes, up to 2 per action).
const DEFAULT_KEYS := {
	"game_left": [KEY_LEFT, KEY_A],
	"game_right": [KEY_RIGHT, KEY_D],
	"game_soft_drop": [KEY_DOWN, KEY_S],
	"game_hard_drop": [KEY_SPACE, KEY_W],
	"game_rotate_cw": [KEY_UP, KEY_X],
	"game_rotate_ccw": [KEY_Z, KEY_CTRL],
	"game_hold": [KEY_C, KEY_SHIFT],
	"game_pause": [KEY_ESCAPE, KEY_P],
}
## Gamepad defaults (buttons, up to 2 per action).
const DEFAULT_PADS := {
	"game_left": [JOY_BUTTON_DPAD_LEFT],
	"game_right": [JOY_BUTTON_DPAD_RIGHT],
	"game_soft_drop": [JOY_BUTTON_DPAD_DOWN],
	"game_hard_drop": [JOY_BUTTON_DPAD_UP],
	"game_rotate_cw": [JOY_BUTTON_A, JOY_BUTTON_Y],
	"game_rotate_ccw": [JOY_BUTTON_B, JOY_BUTTON_X],
	"game_hold": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
	"game_pause": [JOY_BUTTON_START],
}
## Left stick also moves / soft drops.
const STICK := {
	"game_left": [JOY_AXIS_LEFT_X, -1.0],
	"game_right": [JOY_AXIS_LEFT_X, 1.0],
	"game_soft_drop": [JOY_AXIS_LEFT_Y, 1.0],
}

var using_pad := false
var using_touch := false   # on-screen controls shown (phones, tablets)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	using_touch = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	apply_bindings()
	_extend_ui_actions()


func _extend_ui_actions() -> void:
	# menu navigation also with WASD / gamepad stick
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)
	_add_key("ui_accept", KEY_X)
	_add_key("ui_cancel", KEY_Z)
	_add_key("ui_cancel", KEY_BACKSPACE)
	# Godot 4 ships no gamepad button on accept / cancel: A confirms, B backs out
	_add_pad("ui_accept", JOY_BUTTON_A)
	_add_pad("ui_cancel", JOY_BUTTON_B)
	for pair: Array in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
			["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = pair[1]
		ev.axis_value = pair[2]
		if not _has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)


func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _add_pad(action: String, btn: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _has_event(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e.is_match(ev, true):
			return true
	return false


func keys_for(action: String) -> Array:
	var b: Dictionary = Settings.get_value("bindings")
	if b.has(action) and b[action].has("keys"):
		return b[action]["keys"]
	return DEFAULT_KEYS.get(action, [])


func pads_for(action: String) -> Array:
	var b: Dictionary = Settings.get_value("bindings")
	if b.has(action) and b[action].has("pads"):
		return b[action]["pads"]
	return DEFAULT_PADS.get(action, [])


func apply_bindings() -> void:
	for action: String in GAME_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.45)
		for k in keys_for(action):
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(action, ev)
		for btn in pads_for(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(btn)
			InputMap.action_add_event(action, jb)
		if STICK.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = STICK[action][0]
			jm.axis_value = STICK[action][1]
			InputMap.action_add_event(action, jm)
	bindings_changed.emit()


## Replaces binding `slot` (0 or 1) of `action` with the given event.
func rebind(action: String, ev: InputEvent, slot: int = 0) -> void:
	var b: Dictionary = Settings.get_value("bindings").duplicate(true)
	var entry: Dictionary = b.get(action, {"keys": keys_for(action).duplicate(), "pads": pads_for(action).duplicate()})
	if not entry.has("keys"):
		entry["keys"] = keys_for(action).duplicate()
	if not entry.has("pads"):
		entry["pads"] = pads_for(action).duplicate()
	if ev is InputEventKey:
		var code := int((ev as InputEventKey).physical_keycode)
		if code == 0:
			code = int((ev as InputEventKey).keycode)
		# a key can only drive one game action
		for other: String in GAME_ACTIONS:
			if other == action:
				continue
			var oe: Dictionary = b.get(other, {"keys": keys_for(other).duplicate(), "pads": pads_for(other).duplicate()})
			var ok: Array = oe.get("keys", keys_for(other)).duplicate()
			if ok.has(code):
				ok.erase(code)
				oe["keys"] = ok
				if not oe.has("pads"):
					oe["pads"] = pads_for(other).duplicate()
				b[other] = oe
		var keys: Array = entry["keys"]
		while keys.size() <= slot:
			keys.append(0)
		keys[slot] = code
		entry["keys"] = keys.filter(func(k): return int(k) != 0)
	elif ev is InputEventJoypadButton:
		var btn := int((ev as InputEventJoypadButton).button_index)
		for other: String in GAME_ACTIONS:
			if other == action:
				continue
			var oe: Dictionary = b.get(other, {"keys": keys_for(other).duplicate(), "pads": pads_for(other).duplicate()})
			var op: Array = oe.get("pads", pads_for(other)).duplicate()
			if op.has(btn):
				op.erase(btn)
				oe["pads"] = op
				if not oe.has("keys"):
					oe["keys"] = keys_for(other).duplicate()
				b[other] = oe
		var pads: Array = entry["pads"]
		while pads.size() <= slot:
			pads.append(-1)
		pads[slot] = btn
		entry["pads"] = pads.filter(func(p): return int(p) >= 0)
	b[action] = entry
	Settings.set_value("bindings", b)
	apply_bindings()


func reset_bindings() -> void:
	Settings.set_value("bindings", {})
	apply_bindings()


func key_name(code: int) -> String:
	if code <= 0:
		return "-"
	var s := OS.get_keycode_string(code)
	return s if s != "" else "?"


func pad_name(btn: int) -> String:
	match btn:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
	return "Btn %d" % btn


func describe(action: String) -> String:
	if using_pad:
		var p := pads_for(action)
		return pad_name(int(p[0])) if not p.is_empty() else "-"
	var k := keys_for(action)
	return key_name(int(k[0])) if not k.is_empty() else "-"


func toggle_fullscreen() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return
	Settings.set_value("fullscreen", not bool(Settings.get_value("fullscreen")))


func set_touch(on: bool) -> void:
	if on != using_touch:
		using_touch = on
		touch_changed.emit()


func _input(event: InputEvent) -> void:
	# F11 or the gamepad's Select / Back button: fullscreen on and off, anywhere
	if event.is_pressed() and not event.is_echo() and (
			(event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F11)
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK)):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and not using_touch:
		set_touch(true)
	elif (event is InputEventKey or event is InputEventJoypadButton) and using_touch:
		set_touch(false)
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var kb := event is InputEventKey or event is InputEventMouseButton
	if pad and not using_pad:
		using_pad = true
		device_changed.emit(true)
	elif kb and using_pad:
		using_pad = false
		device_changed.emit(false)
