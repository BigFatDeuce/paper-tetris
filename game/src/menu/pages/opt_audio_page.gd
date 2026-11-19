extends MenuPage
## Volumes.

const KEYS := {"master": "master_volume", "music": "music_volume", "sfx": "sfx_volume"}


func _init() -> void:
	title = "SOUND"
	tab_color = "blue"
	menu_width = 520


func _pct(key: String) -> String:
	return "%d%%" % int(round(float(Settings.get_value(key)) * 100.0))


func build_items() -> Array:
	return [
		{"id": "master", "text": "Master", "value": _pct("master_volume")},
		{"id": "music", "text": "Music", "value": _pct("music_volume")},
		{"id": "sfx", "text": "Sound FX", "value": _pct("sfx_volume")},
	]


func step(id: String, dir: int) -> void:
	var key: String = KEYS[id]
	var v := clampf(snappedf(float(Settings.get_value(key)) + dir * 0.05, 0.05), 0.0, 1.0)
	Settings.set_value(key, v)
	menu.set_value_text(id, _pct(key))
	if id == "sfx":
		Audio.sfx("lock")
