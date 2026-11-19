extends MenuPage
## Root of the menu: PLAY, GAME MODES, RECORDS, OPTIONS, CREDITS, QUIT.

const HINTS := {
	"play": "",
	"modes": "Marathon, Sprint, Ultra, Endless, Practice.",
	"records": "Your best runs, saved on this computer.",
	"options": "Sound, controls, gameplay and display.",
	"credits": "Who made all this paper.",
	"quit": "See you soon!",
}


func _init() -> void:
	title = "MENU"
	tab_color = "red"
	menu_width = 420
	center_on = Vector2(960, 700)


func build_items() -> Array:
	var items := [
		{"id": "play", "text": "Play"},
		{"id": "modes", "text": "Game Modes"},
		{"id": "records", "text": "Records"},
		{"id": "options", "text": "Options"},
		{"id": "credits", "text": "Credits"},
	]
	# a web page cannot close its own tab
	if not OS.has_feature("web"):
		items.append({"id": "quit", "text": "Quit"})
	return items


func moved(id: String) -> void:
	if id == "play":
		var m := GameRules.mode_from_id(str(Settings.get_value("last_mode")))
		var t := tr(GameRules.mode_name(m))
		if m in [GameRules.Mode.MARATHON, GameRules.Mode.ENDLESS, GameRules.Mode.PRACTICE]:
			t += tr(", level %d") % int(Settings.get_value("last_level"))
		set_hint(tr("Start %s.") % t)
	else:
		set_hint(HINTS.get(id, ""))


func activate(id: String) -> void:
	match id:
		"play":
			nav.start_last()
		"modes":
			nav.push(preload("res://src/menu/pages/modes_page.gd").new())
		"records":
			nav.push(preload("res://src/menu/pages/records_page.gd").new())
		"options":
			nav.push(preload("res://src/menu/pages/options_page.gd").new())
		"credits":
			nav.go_credits()
		"quit":
			var c := preload("res://src/menu/pages/confirm_page.gd").new()
			c.question = "Quit Paper Tetris?"
			c.on_yes = func(): nav.quit_game()
			nav.push(c)


func back() -> void:
	Audio.sfx("menu_deny")
