extends MenuPage
## Listen to every track and choose the in-game music.

var _ids: Array = []
var _playing := ""


func _init() -> void:
	title = "JUKEBOX"
	tab_color = "gold"
	menu_width = 820
	center_on = Vector2(960, 600)


func _ready() -> void:
	super._ready()
	menu.max_visible = 9
	menu.value_width = 380
	_ids = Audio.music_ids()


func _choice_text() -> String:
	var c := str(Settings.get_value("music_choice"))
	if c == "stage" or not Audio.music_catalog.has(c):
		return "Follow the stage"
	return Audio.music_title(c)


func build_items() -> Array:
	var items: Array = [{"id": "choice", "text": "Game Music", "value": _choice_text()}]
	for id: String in _ids:
		items.append({"id": "t:" + id, "text": Audio.music_title(id), "info": "♪" if id == _playing else ""})
	return items


func moved(id: String) -> void:
	if id == "choice":
		set_hint("Music played during games. \"Follow the stage\" changes with the scenery.")
	else:
		set_hint("Press to listen. Use it as Game Music with the line above.")


func step(id: String, dir: int) -> void:
	if id != "choice":
		return
	var opts: Array = ["stage"] + _ids
	var i := opts.find(str(Settings.get_value("music_choice")))
	Settings.set_value("music_choice", opts[wrapi(i + dir, 0, opts.size())])
	menu.set_value_text("choice", _choice_text())


func activate(id: String) -> void:
	if not id.begins_with("t:"):
		return
	var tid := id.substr(2)
	if _playing != "":
		menu.set_value_text("t:" + _playing, "")
	_playing = tid
	Audio.play_music(tid, 0.6, true)
	menu.set_value_text(id, "♪")


func back() -> void:
	if _playing != "":
		Audio.play_music(nav.MENU_MUSIC, 0.8)
	nav.pop()
