extends MenuPage
## Options hub.

const SUB := {
	"audio": "res://src/menu/pages/opt_audio_page.gd",
	"gameplay": "res://src/menu/pages/opt_gameplay_page.gd",
	"display": "res://src/menu/pages/opt_display_page.gd",
	"controls": "res://src/menu/pages/controls_page.gd",
	"jukebox": "res://src/menu/pages/jukebox_page.gd",
	"sounds": "res://src/menu/pages/sound_test_page.gd",
}
const HINTS := {
	"language": "Game language.",
	"audio": "Master, music and sound effect volumes.",
	"gameplay": "Ghost piece, hold, previews, handling.",
	"display": "Window, effects and the Shy Guy crowd.",
	"controls": "Rebind keyboard and gamepad.",
	"jukebox": "Listen to the music, pick the game music.",
	"sounds": "Audition and swap every sound effect.",
	"reset": "Restore the default options (keeps controls).",
}


func _init() -> void:
	title = "OPTIONS"
	tab_color = "green"
	menu_width = 460
	center_on = Vector2(960, 660)


func build_items() -> Array:
	return [
		{"id": "language", "text": "Language", "value": Lang.NAMES[Lang.current()]},
		{"id": "audio", "text": "Sound"},
		{"id": "gameplay", "text": "Gameplay"},
		{"id": "display", "text": "Display & Effects"},
		{"id": "controls", "text": "Controls"},
		{"id": "jukebox", "text": "Jukebox"},
		{"id": "sounds", "text": "Sound Test"},
		{"id": "reset", "text": "Reset Options"},
	]


func moved(id: String) -> void:
	set_hint(HINTS.get(id, ""))


func step(id: String, dir: int) -> void:
	if id == "language":
		Lang.cycle(dir)
		menu.set_value_text(id, Lang.NAMES[Lang.current()])
		set_hint(HINTS["language"])


func activate(id: String) -> void:
	if SUB.has(id):
		nav.push(load(SUB[id]).new())
	elif id == "reset":
		var c := preload("res://src/menu/pages/confirm_page.gd").new()
		c.question = "Reset all options to default?"
		c.on_yes = func(): Settings.reset_to_defaults()
		nav.push(c)
