extends MenuPage
## Rebind keyboard keys and gamepad buttons. Choose an action, then press
## the new key or button (it replaces the first binding of that device).

var _waiting := ""
var _wait_t := 0.0
var _guard := 0


func _init() -> void:
	title = "CONTROLS"
	tab_color = "blue"
	menu_width = 820
	center_on = Vector2(960, 620)


func _ready() -> void:
	super._ready()
	menu.value_width = 400
	Controls.device_changed.connect(func(_p): if is_visible_in_tree(): refresh())


func _describe(action: String) -> String:
	var keys: Array = Controls.keys_for(action)
	var names: Array = []
	for k in keys:
		names.append(Controls.key_name(int(k)))
	var pads: Array = Controls.pads_for(action)
	var pad := Controls.pad_name(int(pads[0])) if not pads.is_empty() else "-"
	return "%s   %s" % [" / ".join(names) if not names.is_empty() else "-", pad]


func build_items() -> Array:
	var items: Array = []
	for a: String in Controls.GAME_ACTIONS:
		items.append({"id": a, "text": Controls.ACTION_LABELS[a], "info": _describe(a)})
	items.append({"id": "reset", "text": "Reset Controls"})
	return items


func moved(id: String) -> void:
	if _waiting != "":
		return
	if id == "reset":
		set_hint("Back to the default keys and buttons.")
	else:
		set_hint("Choose an action, then press a key or a gamepad button.")


func activate(id: String) -> void:
	if id == "reset":
		Controls.reset_bindings()
		refresh()
		Audio.sfx("pop")
		return
	_waiting = id
	_wait_t = 0.0
	_guard = 6
	menu.set_active(false)
	menu.set_value_text(id, "...")
	set_hint(tr("Press the new key or button for \"%s\"  (Backspace: cancel)") % tr(Controls.ACTION_LABELS[id]))


func _process(delta: float) -> void:
	super._process(delta)
	if _waiting == "":
		return
	if _guard > 0:
		_guard -= 1
	_wait_t += delta
	if _wait_t > 6.0:
		_finish()


func _input(event: InputEvent) -> void:
	if _waiting == "" or _guard > 0:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var k := event as InputEventKey
		get_viewport().set_input_as_handled()
		if k.physical_keycode == KEY_BACKSPACE or k.keycode == KEY_BACKSPACE:
			Audio.sfx("menu_back")
			_finish()
			return
		Controls.rebind(_waiting, k, 0)
		Audio.sfx("menu_select")
		_finish()
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		Controls.rebind(_waiting, event, 0)
		Audio.sfx("menu_select")
		_finish()


func _finish() -> void:
	_waiting = ""
	refresh()
	menu.set_active(true)
	moved(menu.current_id())
