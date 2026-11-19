extends MenuPage
## Display & effects.

const CROWD := ["None", "Calm", "Lively", "Party", "Random"]
const SHAKE := ["Off", "Light", "Full"]


func _init() -> void:
	title = "DISPLAY"
	tab_color = "purple"
	menu_width = 560


func _on(key: String) -> String:
	return "On" if Settings.get_value(key) else "Off"


func build_items() -> Array:
	return [
		{"id": "fullscreen", "text": "Fullscreen", "value": _on("fullscreen")},
		{"id": "vsync", "text": "V-Sync", "value": _on("vsync")},
		{"id": "screen_shake", "text": "Screen Shake", "value": SHAKE[clampi(int(Settings.get_value("screen_shake")), 0, 2)]},
		{"id": "particles", "text": "Confetti", "value": _on("particles")},
		{"id": "crowd", "text": "Shy Guy Crowd", "value": CROWD[clampi(int(Settings.get_value("crowd")), 0, 4)]},
		{"id": "show_fps", "text": "Show FPS", "value": _on("show_fps")},
	]


func moved(id: String) -> void:
	match id:
		"crowd": set_hint("How many Shy Guys hang around. Random picks a new troupe every time. Purely for show!")
		"particles": set_hint("Paper confetti and sparkles.")
		"screen_shake": set_hint("The diorama shakes on big drops and Tetrises. Off keeps the screen still.")
		_: set_hint("")


func step(id: String, dir: int) -> void:
	if id == "crowd":
		Settings.set_value("crowd", wrapi(int(Settings.get_value("crowd")) + dir, 0, 5))
		menu.set_value_text(id, CROWD[int(Settings.get_value("crowd"))])
		return
	if id == "screen_shake":
		Settings.set_value(id, wrapi(int(Settings.get_value(id)) + dir, 0, 3))
		menu.set_value_text(id, SHAKE[int(Settings.get_value(id))])
		return
	Settings.set_value(id, not Settings.get_value(id))
	menu.set_value_text(id, _on(id))
