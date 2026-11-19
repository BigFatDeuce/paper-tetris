extends MenuPage
## Gameplay & handling options.

const DROP := [5.0, 10.0, 20.0, 40.0, 80.0]


func _init() -> void:
	title = "GAMEPLAY"
	tab_color = "red"
	menu_width = 600


func _on(key: String) -> String:
	return "On" if Settings.get_value(key) else "Off"


func _ms(key: String) -> String:
	var v := float(Settings.get_value(key))
	if key == "arr" and v <= 0.0:
		return "Instant"
	return "%d ms" % int(round(v * 1000.0))


func build_items() -> Array:
	return [
		{"id": "ghost", "text": "Ghost Piece", "value": _on("ghost")},
		{"id": "hold", "text": "Hold", "value": _on("hold")},
		{"id": "next_count", "text": "Next Pieces", "value": str(Settings.get_value("next_count"))},
		{"id": "grid", "text": "Board Grid", "value": _on("grid")},
		{"id": "das", "text": "Auto-Shift Delay", "value": _ms("das")},
		{"id": "arr", "text": "Auto-Shift Speed", "value": _ms("arr")},
		{"id": "soft", "text": "Soft Drop Speed", "value": "x%d" % int(Settings.get_value("soft_drop_factor"))},
	]


func moved(id: String) -> void:
	match id:
		"ghost": set_hint("Shows where the piece will land.")
		"hold": set_hint("Keep a piece aside once per drop.")
		"next_count": set_hint("How many upcoming pieces are shown.")
		"grid": set_hint("Faint lines inside the well.")
		"das": set_hint("Wait before a held direction starts repeating.")
		"arr": set_hint("Time between repeated moves.")
		"soft": set_hint("How fast Soft Drop pulls the piece down.")


func step(id: String, dir: int) -> void:
	match id:
		"ghost", "hold", "grid":
			Settings.set_value(id, not Settings.get_value(id))
			menu.set_value_text(id, _on(id))
		"next_count":
			Settings.set_value(id, wrapi(int(Settings.get_value(id)) + dir, 0, 6))
			menu.set_value_text(id, str(Settings.get_value(id)))
		"das":
			var v := clampf(float(Settings.get_value("das")) + dir / 60.0, 3.0 / 60.0, 20.0 / 60.0)
			Settings.set_value("das", snappedf(v, 0.001))
			menu.set_value_text(id, _ms("das"))
		"arr":
			var a := clampf(float(Settings.get_value("arr")) + dir / 60.0, 0.0, 6.0 / 60.0)
			if a < 0.5 / 60.0:
				a = 0.0
			Settings.set_value("arr", snappedf(a, 0.001))
			menu.set_value_text(id, _ms("arr"))
		"soft":
			var i := DROP.find(float(Settings.get_value("soft_drop_factor")))
			if i < 0:
				i = 2
			Settings.set_value("soft_drop_factor", DROP[wrapi(i + dir, 0, DROP.size())])
			menu.set_value_text(id, "x%d" % int(Settings.get_value("soft_drop_factor")))
