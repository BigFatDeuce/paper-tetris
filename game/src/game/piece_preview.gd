class_name PiecePreview
extends Control
## Draws one tetromino centred in its rect (Hold / Next boxes).

const TEX_DIR := "res://assets/ui/"

@export var cell := 44.0
@export var small := false

var type := 0:
	set(v):
		if v != type:
			type = v
			_pop = 1.0
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()

var _pop := 0.0
static var _cache := {}


static func block_texture(t: int, use_small: bool) -> Texture2D:
	var key := "%d_%s" % [t, use_small]
	if not _cache.has(key):
		var n: String = Tetromino.NAMES[t] if t > 0 else "X"
		_cache[key] = load(TEX_DIR + "block_%s%s.png" % [n, "_small" if use_small else ""])
	return _cache[key]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 5.0, 0.0)
		queue_redraw()


func _draw() -> void:
	if type <= 0:
		return
	var cells := Tetromino.cells(type, 0)
	var mn := Vector2i(99, 99)
	var mx := Vector2i(-99, -99)
	for c: Vector2i in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var dims := Vector2(mx - mn + Vector2i.ONE) * cell
	var s := 1.0 + 0.12 * sin(_pop * PI)
	var origin := size * 0.5 - dims * 0.5 * s
	var tex := block_texture(type if not dimmed else 0, small)
	var mod := Color(1, 1, 1, 0.75) if dimmed else Color.WHITE
	for c: Vector2i in cells:
		var p := origin + Vector2(c - mn) * cell * s
		draw_texture_rect(tex, Rect2(p, Vector2(cell, cell) * s), false, mod)
