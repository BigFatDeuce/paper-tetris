extends MenuPage
## Pick a game mode; shows its description and personal best.

var _blurb: Label
var _best: Label


func _init() -> void:
	title = "GAME MODES"
	tab_color = "gold"
	menu_width = 560
	center_on = Vector2(960, 640)


func _ready() -> void:
	super._ready()
	var sep := ColorRect.new()
	sep.color = Color(UIKit.INK_SOFT, 0.3)
	sep.custom_minimum_size = Vector2(0, 3)
	extra.add_child(sep)
	_blurb = UIKit.label("", 2, UIKit.INK)
	_blurb.custom_minimum_size = Vector2(menu_width, 80)
	extra.add_child(_blurb)
	_best = UIKit.label("", 2, UIKit.BLUE)
	extra.add_child(_best)


func build_items() -> Array:
	var items: Array = []
	for i in GameRules.MODE_IDS.size():
		items.append({"id": GameRules.MODE_IDS[i], "text": GameRules.MODE_NAMES[i]})
	return items


func open() -> void:
	menu.index = maxi(GameRules.MODE_IDS.find(str(Settings.get_value("last_mode"))), 0)
	await super.open()


func moved(id: String) -> void:
	var m := GameRules.mode_from_id(id)
	_blurb.text = GameRules.MODE_BLURBS[m]
	if m == GameRules.Mode.PRACTICE:
		_best.text = "No records in Practice."
		return
	var b := SaveData.best(id)
	if b.is_empty():
		_best.text = "Best: none yet"
	elif m == GameRules.Mode.SPRINT:
		_best.text = tr("Best: %s") % UIKit.format_time(float(b.get("time", 0.0)))
	else:
		_best.text = tr("Best: %s pts  (%d lines)") % [UIKit.format_int(int(b.get("score", 0))), int(b.get("lines", 0))]


func activate(id: String) -> void:
	var s := preload("res://src/menu/pages/setup_page.gd").new()
	s.mode_id = id
	nav.push(s)
