extends MenuPage
## Top 10 per mode + lifetime totals.

var mode := 0
var _table: GridContainer
var _life: Label


func _init() -> void:
	title = "RECORDS"
	tab_color = "blue"
	menu_width = 760
	center_on = Vector2(960, 600)


func _ready() -> void:
	super._ready()
	mode = GameRules.mode_from_id(str(Settings.get_value("last_mode")))
	if mode == GameRules.Mode.PRACTICE:
		mode = GameRules.Mode.MARATHON
	_table = GridContainer.new()
	_table.columns = 5
	_table.add_theme_constant_override("h_separation", 34)
	_table.add_theme_constant_override("v_separation", 2)
	extra.add_child(_table)
	var sep := ColorRect.new()
	sep.color = Color(UIKit.INK_SOFT, 0.3)
	sep.custom_minimum_size = Vector2(0, 3)
	extra.add_child(sep)
	_life = UIKit.label("", 2, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	extra.add_child(_life)


func _modes() -> Array:
	return [GameRules.Mode.MARATHON, GameRules.Mode.SPRINT, GameRules.Mode.ULTRA, GameRules.Mode.ENDLESS]


func build_items() -> Array:
	return [
		{"id": "mode", "text": "Mode", "value": GameRules.mode_name(mode)},
		{"id": "erase", "text": "Erase All Records"},
	]


func open() -> void:
	_fill()
	await super.open()


func step(id: String, dir: int) -> void:
	if id != "mode":
		return
	var ms := _modes()
	mode = ms[wrapi(ms.find(mode) + dir, 0, ms.size())]
	menu.set_value_text("mode", GameRules.mode_name(mode))
	_fill()


func activate(id: String) -> void:
	if id == "erase":
		var c := preload("res://src/menu/pages/confirm_page.gd").new()
		c.question = "Erase every record? This cannot be undone."
		c.on_yes = func():
			SaveData.clear_all()
			_fill()
		nav.push(c)


func _cell(text: String, color := UIKit.INK, right := false) -> Label:
	return UIKit.label(text, 2, color, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)


func _fill() -> void:
	for c in _table.get_children():
		_table.remove_child(c)
		c.queue_free()
	var id := GameRules.mode_id(mode)
	var sprint := mode == GameRules.Mode.SPRINT
	var heads := ["#", "TIME" if sprint else "SCORE", "LINES", "PIECES/S" if sprint else "TIME", "DATE"]
	for h: String in heads:
		_table.add_child(_cell(h, UIKit.RED))
	var list := SaveData.records(id)
	for i in 10:
		var col := UIKit.BLUE if i == 0 else UIKit.INK
		if i < list.size():
			var e: Dictionary = list[i]
			_table.add_child(_cell("%d." % (i + 1), col))
			if sprint:
				_table.add_child(_cell(UIKit.format_time(float(e.get("time", 0.0))), col, true))
				_table.add_child(_cell(str(e.get("lines", 0)), col, true))
				_table.add_child(_cell("%.2f" % float(e.get("pps", 0.0)), col, true))
			else:
				_table.add_child(_cell(UIKit.format_int(int(e.get("score", 0))), col, true))
				_table.add_child(_cell(str(e.get("lines", 0)), col, true))
				_table.add_child(_cell(UIKit.format_time(float(e.get("time", 0.0)), false), col, true))
			_table.add_child(_cell(str(e.get("date", "")), UIKit.INK_SOFT))
		else:
			_table.add_child(_cell("%d." % (i + 1), UIKit.DISABLED))
			for k in 3:
				_table.add_child(_cell("-", UIKit.DISABLED, true))
			_table.add_child(_cell("", UIKit.DISABLED))
	var life: Dictionary = SaveData.data.get("lifetime", {})
	_life.text = tr("Games %d   Lines %s   Tetrises %d   Play time %s") % [
		int(life.get("games", 0)), UIKit.format_int(int(life.get("lines", 0))),
		int(life.get("tetrises", 0)), UIKit.format_time(float(life.get("play_time", 0.0)), false)]
