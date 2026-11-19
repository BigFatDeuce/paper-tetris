extends MenuPage
## Start parameters of a mode (level, stage, practice options).

var mode_id := "marathon"
var mode := 0
var level := 1
var stage := "auto"


func _init() -> void:
	tab_color = "green"
	menu_width = 560
	center_on = Vector2(960, 660)


func _ready() -> void:
	super._ready()
	mode = GameRules.mode_from_id(mode_id)
	title = Lang.t(GameRules.mode_name(mode)).to_upper()
	level = clampi(int(Settings.get_value("last_level")), 1, _max_level())
	stage = str(Settings.get_value("last_stage"))
	if stage != "auto" and not StageLibrary.STAGES.has(stage):
		stage = "auto"


func _max_level() -> int:
	match mode:
		GameRules.Mode.MARATHON: return 15
		GameRules.Mode.ENDLESS, GameRules.Mode.PRACTICE: return 20
	return 1


func _stage_text() -> String:
	if stage == "auto":
		if mode == GameRules.Mode.MARATHON or mode == GameRules.Mode.ENDLESS:
			return "Journey"
		return "Auto"
	return StageLibrary.stage_name(stage)


func build_items() -> Array:
	var items: Array = [{"id": "start", "text": "Start!"}]
	if _max_level() > 1:
		items.append({"id": "level", "text": "Start Level", "value": str(level)})
	items.append({"id": "stage", "text": "Stage", "value": _stage_text()})
	if mode == GameRules.Mode.PRACTICE:
		items.append({"id": "gravity", "text": "Gravity", "value": "On" if Settings.get_value("practice_gravity") else "Off"})
		items.append({"id": "level_up", "text": "Level Up", "value": "On" if Settings.get_value("practice_level_up") else "Off"})
	return items


func moved(id: String) -> void:
	match id:
		"start": set_hint("Ready? Let's go!")
		"level": set_hint("Higher levels fall faster.")
		"stage":
			if mode == GameRules.Mode.MARATHON or mode == GameRules.Mode.ENDLESS:
				set_hint("Journey: travel to a new stage every 2 levels.")
			else:
				set_hint("Where the Shy Guys will watch you play.")
		"gravity": set_hint("Off: pieces only fall when you drop them.")
		"level_up": set_hint("Raise the level every 10 lines.")


func step(id: String, dir: int) -> void:
	match id:
		"level":
			level = wrapi(level + dir, 1, _max_level() + 1)
			menu.set_value_text(id, str(level))
		"stage":
			var opts: Array = ["auto"] + StageLibrary.ids()
			var i := opts.find(stage)
			stage = opts[wrapi(i + dir, 0, opts.size())]
			menu.set_value_text(id, _stage_text())
		"gravity":
			Settings.set_value("practice_gravity", not Settings.get_value("practice_gravity"))
			menu.set_value_text(id, "On" if Settings.get_value("practice_gravity") else "Off")
		"level_up":
			Settings.set_value("practice_level_up", not Settings.get_value("practice_level_up"))
			menu.set_value_text(id, "On" if Settings.get_value("practice_level_up") else "Off")


func activate(id: String) -> void:
	if id != "start":
		step(id, 1)
		return
	Settings.set_value("last_mode", mode_id)
	if _max_level() > 1:
		Settings.set_value("last_level", level)
	Settings.set_value("last_stage", stage)
	nav.start_game({"mode": mode_id, "start_level": level if _max_level() > 1 else 1, "stage": stage})
