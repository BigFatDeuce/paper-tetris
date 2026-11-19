extends MenuPage
## Audition every game sound and swap it for any sample of the library
## (the original designs or the raw Paper Mario samples). Saved in options.

const EVENTS := [
	["move", "Move"], ["rotate", "Rotate"], ["rotate_fail", "Rotate Blocked"],
	["soft_drop", "Piece Lands"], ["lock", "Lock"], ["hard_drop", "Hard Drop"],
	["hold", "Hold"], ["clear1", "Single"], ["clear2", "Double"], ["clear3", "Triple"],
	["clear4", "Tetris"], ["tspin", "T-Spin"], ["b2b", "Back-to-Back"], ["combo", "Combo"],
	["perfect", "Perfect Clear"], ["level_up", "Level Up"], ["count", "Countdown"],
	["go", "Go!"], ["victory", "Clear Jingle"], ["game_over", "Game Over"],
	["new_record", "New Record"], ["danger", "Danger"], ["tally", "Score Tally"],
	["menu_move", "Menu Move"], ["menu_select", "Menu Select"], ["menu_back", "Menu Back"],
	["menu_tick", "Menu Value"], ["menu_deny", "Menu Deny"], ["window_open", "Window Open"],
	["window_close", "Window Close"], ["pause", "Pause"], ["page_turn", "Page Turn"],
	["stage_pop", "Stage Pop-Up"], ["transition_close", "Iris Close"],
	["transition_open", "Iris Open"],
]

var _options: Array = []   # "" = default, else a file path


func _init() -> void:
	title = "SOUND TEST"
	tab_color = "purple"
	menu_width = 820
	center_on = Vector2(960, 600)


func _ready() -> void:
	super._ready()
	menu.max_visible = 9
	menu.value_width = 380
	_options = [""]
	# works both from the project and from an exported build (".import")
	var seen := {}
	var dir := DirAccess.open("res://assets/sfx/")
	if dir:
		for f in dir.get_files():
			var n := f.trim_suffix(".import").trim_suffix(".remap")
			if n.ends_with(".wav") and not seen.has(n):
				seen[n] = true
				_options.append("res://assets/sfx/" + n)
	for n in _library():
		_options.append("res://assets/sfx/pm/%s.wav" % n)


func _library() -> Array:
	var path := "res://data/sfx_library.json"
	if not FileAccess.file_exists(path):
		return []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_ARRAY else []


func _current(ev: String) -> String:
	var over: Dictionary = Settings.get_value("sfx_overrides")
	return str(over.get(ev, ""))


func _label(path: String) -> String:
	if path == "":
		return "Default"
	var f := path.get_file().get_basename()
	if path.contains("/pm/"):
		return "PM " + f
	return f.capitalize()


func build_items() -> Array:
	var items: Array = []
	for e: Array in EVENTS:
		items.append({"id": e[0], "text": e[1], "value": _label(_current(e[0]))})
	items.append({"id": "reset", "text": "Reset All Sounds"})
	return items


func moved(id: String) -> void:
	if id == "reset":
		set_hint("Every sound back to its original design.")
	else:
		set_hint("Left / Right: try another sample.  Confirm: play.")


func step(id: String, dir: int) -> void:
	if id == "reset":
		return
	var i := _options.find(_current(id))
	var next: String = _options[wrapi(i + dir, 0, _options.size())]
	var over: Dictionary = Settings.get_value("sfx_overrides").duplicate()
	if next == "":
		over.erase(id)
	else:
		over[id] = next
	Settings.set_value("sfx_overrides", over)
	menu.set_value_text(id, _label(next))
	_play(id)


func activate(id: String) -> void:
	if id == "reset":
		Settings.set_value("sfx_overrides", {})
		refresh()
		Audio.sfx("pop")
		return
	_play(id)


func _play(id: String) -> void:
	# plays after the menu tick so both are audible
	await get_tree().create_timer(0.06).timeout
	Audio.sfx(id)
