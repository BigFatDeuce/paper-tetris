class_name Tetromino
extends RefCounted
## Static data for the seven tetrominoes: shapes, Super Rotation System
## kicks and default colours. Grid coordinates: x to the right, y DOWN.

enum Type { NONE = 0, I = 1, O = 2, T = 3, S = 4, Z = 5, J = 6, L = 7 }

const TYPES: Array[int] = [Type.I, Type.O, Type.T, Type.S, Type.Z, Type.J, Type.L]
const NAMES := ["", "I", "O", "T", "S", "Z", "J", "L"]

## Spawn-orientation cells inside each piece's bounding box (y down).
const SPAWN_CELLS := {
	Type.I: [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	Type.O: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Type.T: [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Type.S: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Type.Z: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	Type.J: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Type.L: [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}

## Bounding box size used for rotation.
const BOX_SIZE := {
	Type.I: 4, Type.O: 2, Type.T: 3, Type.S: 3, Type.Z: 3, Type.J: 3, Type.L: 3,
}

## Guideline-like colours, warmed up for the paper look.
const COLORS := {
	Type.I: Color("3ec6ee"),
	Type.O: Color("ffd23f"),
	Type.T: Color("b05ce0"),
	Type.S: Color("5cc83c"),
	Type.Z: Color("ec4a3c"),
	Type.J: Color("3e6ee8"),
	Type.L: Color("f68a2e"),
}

## SRS wall kicks, written in SRS convention (y UP). Converted on use.
## Key: "from>to" with states 0, 1 (R), 2, 3 (L).
const KICKS_JLSTZ := {
	"0>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"1>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	"1>2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	"2>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"2>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"3>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"3>0": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"0>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
}
const KICKS_I := {
	"0>1": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	"1>0": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	"1>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
	"2>1": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	"2>3": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	"3>2": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	"3>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	"0>3": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
}

static var _cells_cache := {}


## Cells of `type` in rotation state `rot` (0..3), relative to the box origin.
static func cells(type: int, rot: int) -> Array:
	var key := type * 4 + posmod(rot, 4)
	if _cells_cache.has(key):
		return _cells_cache[key]
	var result: Array = []
	if type == Type.O:
		result = SPAWN_CELLS[type].duplicate()
		_cells_cache[key] = result
		return result
	var n: int = BOX_SIZE[type]
	for c: Vector2i in SPAWN_CELLS[type]:
		var p := c
		for i in posmod(rot, 4):
			# clockwise rotation inside an n x n box, y down
			p = Vector2i(n - 1 - p.y, p.x)
		result.append(p)
	_cells_cache[key] = result
	return result


## Kick offsets (already converted to y-down grid) for a rotation.
static func kicks(type: int, from_rot: int, to_rot: int) -> Array:
	if type == Type.O:
		return [Vector2i.ZERO]
	var table: Dictionary = KICKS_I if type == Type.I else KICKS_JLSTZ
	var key := "%d>%d" % [posmod(from_rot, 4), posmod(to_rot, 4)]
	var out: Array = []
	for k: Vector2i in table[key]:
		out.append(Vector2i(k.x, -k.y))
	return out


## Spawn x of the bounding box on a 10-wide board.
static func spawn_x(type: int, board_width: int) -> int:
	var n: int = BOX_SIZE[type]
	if type == Type.O:
		return board_width / 2 - 1
	# left of centre, as in the guideline: JLSTZ in columns 3-5, I in 3-6
	@warning_ignore("integer_division")
	return (board_width - n) / 2


static func color(type: int) -> Color:
	return COLORS.get(type, Color(0.6, 0.6, 0.6))
