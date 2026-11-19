class_name TestBase
extends RefCounted
## Tiny assertion helpers shared by the test suites.

var _failed := false
var _messages: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_messages.append(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		_failed = true
		_messages.append("%s: got %s, expected %s" % [msg, str(a), str(b)])


## Engine with a fixed seed, already started.
func make_engine(mode := GameRules.Mode.MARATHON, opts := {}) -> TetrisEngine:
	var o := opts.duplicate()
	if not o.has("seed"):
		o["seed"] = 1234
	var e := TetrisEngine.new(GameRules.for_mode(mode, o))
	e.rules.line_clear_delay = 0.0
	return e


## Fills the bottom of the board from text rows ('#' = block, '.' = empty).
## The last string is the bottom row.
func fill_rows(e: TetrisEngine, rows: Array) -> void:
	var y := TetrisEngine.HEIGHT - rows.size()
	for line: String in rows:
		for x in TetrisEngine.WIDTH:
			e.set_cell(x, y, 8 if line[x] == "#" else 0)
		y += 1


## Forces the active piece (replacing whatever spawned).
func force_piece(e: TetrisEngine, type: int, pos: Vector2i, rot := 0) -> void:
	e.active_type = type
	e.active_rot = rot
	e.active_pos = pos
	e.state = TetrisEngine.State.FALLING
	e._lowest_y = pos.y
	e._last_was_rotation = false
	e._lock_timer = 0.0
	e._lock_resets = 0


func row_text(e: TetrisEngine, y: int) -> String:
	var s := ""
	for x in TetrisEngine.WIDTH:
		s += "#" if e.get_cell(x, y) != 0 else "."
	return s
