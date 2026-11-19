class_name BowserCameo
extends Node2D
## Bowser watching from the back of his castle (Bowser's Castle stage): the
## original idle animation, plus a few reactions to the game. Purely for
## show, like the Shy Guys: listens to Events, never talks back.

const SHEET := "res://assets/sprites/bowser/bowser_idle.png"
const META := "res://assets/sprites/bowser/bowser_idle.json"
const PX := 3.0

var _spr: Sprite2D
var _cell := Vector2i(114, 116)
var _cols := 12
var _durs: Array = []
var _frame := 0
var _t := 0.0
var _busy := false


func _ready() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
	if typeof(meta) == TYPE_DICTIONARY:
		_cell = Vector2i(int(meta["cell"][0]), int(meta["cell"][1]))
		_cols = int(meta["cols"])
		_durs = meta["durations_ms"]
	var shadow := Sprite2D.new()
	shadow.texture = _shadow_tex()
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.scale = Vector2(2.6, 0.7)
	add_child(shadow)
	_spr = Sprite2D.new()
	_spr.texture = load(SHEET)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.region_enabled = true
	_spr.centered = false
	_spr.scale = Vector2(PX, PX)
	# feet on this node's origin
	_spr.position = Vector2(-_cell.x * PX * 0.5, -_cell.y * PX + 6)
	add_child(_spr)
	_show(0)
	Events.game_event.connect(_on_event)


func _shadow_tex() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.width = 64
	g.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color.WHITE)
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	return g


func _show(i: int) -> void:
	_frame = i
	_spr.region_rect = Rect2((i % _cols) * _cell.x, (i / _cols) * _cell.y, _cell.x, _cell.y)


func _process(delta: float) -> void:
	if _durs.is_empty():
		return
	_t += delta * 1000.0
	while _t >= float(_durs[_frame]):
		_t -= float(_durs[_frame])
		_show((_frame + 1) % _durs.size())


func _on_event(kind: StringName, data: Dictionary) -> void:
	if _busy or not is_inside_tree():
		return
	match kind:
		&"tetris", &"perfect":
			_stomp()
		&"danger":
			if bool(data.get("on", false)):
				_shake(0.8)
		&"game_over":
			_laugh()
		&"hard_drop":
			if int(data.get("rows", 0)) >= 12:
				_shake(0.3)


## A furious hop: Bowser does not like your Tetris.
func _stomp() -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_spr, "position:y", _spr.position.y - 46, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "position:y", _spr.position.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Audio.sfx("hard_drop", 0.6, -6.0))
	tw.tween_property(self, "scale", Vector2(1.08, 0.92), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): _busy = false)


func _shake(dur: float) -> void:
	_busy = true
	var tw := create_tween()
	var n := int(dur / 0.05)
	for i in n:
		tw.tween_property(_spr, "rotation", deg_to_rad(3.0 if i % 2 == 0 else -3.0), 0.05)
	tw.tween_property(_spr, "rotation", 0.0, 0.05)
	tw.tween_callback(func(): _busy = false)


## Game over: Bowser laughs, bobbing on his feet.
func _laugh() -> void:
	_busy = true
	var base := _spr.position.y
	var tw := create_tween()
	for i in 6:
		tw.tween_property(_spr, "position:y", base - 14, 0.09)
		tw.tween_property(_spr, "position:y", base, 0.09)
	tw.tween_callback(func(): _busy = false)
