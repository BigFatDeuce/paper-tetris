class_name BoardView
extends Node2D
## Draws the well: grid, locked blocks, ghost, active piece and the
## line-clear / lock / hard-drop / top-out animations. Read-only view of
## the engine (never modifies it).

const CELL := 44
const W := TetrisEngine.WIDTH
const VIS := TetrisEngine.VISIBLE
const HID := TetrisEngine.HIDDEN
const SHOW_ABOVE := 2   # hidden rows drawn above the well

const WELL_COLOR := Color(0.10, 0.08, 0.20, 0.93)
const GRID_COLOR := Color(1, 1, 1, 0.055)
const COL_TINT := Color(1, 1, 1, 0.018)

var engine: TetrisEngine
var ghost_enabled := true
var grid_enabled := true
var danger := false

var _tex := {}
var _ghost_tex: Texture2D
var _flash_tex: Texture2D
var _clear_rows: Array = []
var _clear_t := 0.0
var _clear_dur := 0.32
var _lock_flash: Array = []      # [{cells, t}]
var _trails: Array = []          # [{x0, x1, y0, y1, t, color}]
var _row_offset := {}            # row -> start offset in px (rows falling after a clear)
var _fall_t := 0.0
const FALL_G := 9000.0
var _topout_rows := -1           # rows (from the bottom) greyed by the game over
var _time := 0.0
var _piece_bounce := 0.0


func _ready() -> void:
	for t: int in Tetromino.TYPES:
		_tex[t] = load("res://assets/ui/block_%s.png" % Tetromino.NAMES[t])
	_tex[8] = load("res://assets/ui/block_X.png")
	_ghost_tex = load("res://assets/ui/block_ghost.png")
	_flash_tex = load("res://assets/ui/block_flash.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func bind(e: TetrisEngine) -> void:
	engine = e
	engine.lines_cleared.connect(_on_lines_cleared)
	engine.rows_collapsed.connect(_on_rows_collapsed)
	engine.piece_locked.connect(_on_locked)
	engine.hard_dropped.connect(_on_hard_drop)
	engine.danger_changed.connect(func(on): danger = on)
	_clear_dur = maxf(engine.rules.line_clear_delay, 0.05)


func well_size() -> Vector2:
	return Vector2(W * CELL, VIS * CELL)


## Board cell -> local pixel position (top-left of the cell).
func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL, (c.y - HID) * CELL)


func cell_center_global(c: Vector2i) -> Vector2:
	return to_global(cell_pos(c) + Vector2(CELL, CELL) * 0.5)


func _process(delta: float) -> void:
	_time += delta
	if not _clear_rows.is_empty():
		_clear_t += delta
	for f in _lock_flash:
		f["t"] += delta
	_lock_flash = _lock_flash.filter(func(f): return f["t"] < 0.22)
	for tr in _trails:
		tr["t"] += delta
	_trails = _trails.filter(func(tr): return tr["t"] < 0.3)
	if not _row_offset.is_empty():
		_fall_t += delta
		if _fall_t > 0.5:
			_row_offset.clear()
	_piece_bounce = move_toward(_piece_bounce, 0.0, delta * 6.0)
	queue_redraw()


func _on_lines_cleared(rows: Array, _res: Dictionary) -> void:
	if rows.is_empty():
		return
	_clear_rows = rows.duplicate()
	_clear_t = 0.0


func _on_rows_collapsed(rows: Array) -> void:
	_clear_rows = []
	_row_offset.clear()
	# map every surviving row to its new position and start it from where
	# it was, so the stack visibly drops into place
	var cleared := {}
	for r: int in rows:
		cleared[r] = true
	var f := TetrisEngine.HEIGHT - 1
	for o in range(TetrisEngine.HEIGHT - 1, -1, -1):
		if cleared.has(o):
			continue
		if f - o > 0:
			_row_offset[f] = -float(f - o) * CELL
		f -= 1
	_fall_t = 0.0


func _on_locked(cells: Array, _type: int, _tspin: int) -> void:
	_lock_flash.append({"cells": cells.duplicate(), "t": 0.0})


func _on_hard_drop(rows: int, cells: Array) -> void:
	if rows <= 0:
		return
	var xs := {}
	for c: Vector2i in cells:
		var top: int = xs.get(c.x, 999)
		xs[c.x] = mini(top, c.y)
	var col: Color = Tetromino.color(engine.active_type if engine.active_type != 0 else 1)
	for x: int in xs.keys():
		_trails.append({"x": x, "y0": xs[x] - rows, "y1": xs[x], "t": 0.0, "color": col})


func set_trail_color(c: Color) -> void:
	for tr in _trails:
		tr["color"] = c


func start_topout() -> void:
	_topout_rows = 0
	var tw := create_tween()
	tw.tween_method(func(v: float): _topout_rows = int(v), 0.0, float(VIS + SHOW_ABOVE), 0.9)


func bounce_piece() -> void:
	_piece_bounce = 1.0


func _fall_offset(y: int) -> float:
	if not _row_offset.has(y):
		return 0.0
	return minf(float(_row_offset[y]) + 0.5 * FALL_G * _fall_t * _fall_t, 0.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var ws := well_size()
	# well
	draw_rect(Rect2(Vector2.ZERO, ws), WELL_COLOR)
	for x in W:
		if x % 2 == 0:
			draw_rect(Rect2(x * CELL, 0, CELL, ws.y), COL_TINT)
	if grid_enabled:
		for x in range(1, W):
			draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ws.y), GRID_COLOR, 1.0)
		for y in range(1, VIS):
			draw_line(Vector2(0, y * CELL), Vector2(ws.x, y * CELL), GRID_COLOR, 1.0)
	if danger:
		var a := 0.10 + 0.08 * sin(_time * 6.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(ws.x, CELL * 4)), Color(1, 0.2, 0.15, a))
	if engine == null:
		return
	# hard drop trails
	for tr in _trails:
		var k: float = 1.0 - tr["t"] / 0.3
		var c: Color = tr["color"]
		var top := cell_pos(Vector2i(tr["x"], tr["y0"]))
		var bot := cell_pos(Vector2i(tr["x"], tr["y1"]))
		var r := Rect2(top + Vector2(CELL * 0.18, 0), Vector2(CELL * 0.64, bot.y - top.y + CELL * 0.5))
		r = r.intersection(Rect2(Vector2(0, -SHOW_ABOVE * CELL), ws + Vector2(0, SHOW_ABOVE * CELL)))
		draw_rect(r, Color(c.r, c.g, c.b, 0.35 * k))
		draw_rect(r.grow_individual(-CELL * 0.18, 0, -CELL * 0.18, 0), Color(1, 1, 1, 0.35 * k))
	# locked blocks
	var clear_k := clampf(_clear_t / _clear_dur, 0.0, 1.0)
	for y in range(HID - SHOW_ABOVE, TetrisEngine.HEIGHT):
		var clearing := _clear_rows.has(y)
		var off := _fall_offset(y)
		var grey := _topout_rows >= 0 and (TetrisEngine.HEIGHT - 1 - y) < _topout_rows
		for x in W:
			var v := engine.get_cell(x, y)
			if v == 0:
				continue
			var p := cell_pos(Vector2i(x, y)) + Vector2(0, off)
			var tex: Texture2D = _tex[8] if grey else _tex.get(v, _tex[8])
			if clearing:
				# squash towards the row centre, then vanish
				var s := 1.0 - clear_k * clear_k
				var cx := p.x + CELL * 0.5
				var rect := Rect2(cx - CELL * 0.5 * (1.0 - clear_k * 0.3), p.y + CELL * 0.5 * (1.0 - s), CELL * (1.0 - clear_k * 0.3), CELL * s)
				draw_texture_rect(tex, rect, false)
				var fl := 0.85 * (1.0 - clear_k) + 0.25 * sin(_clear_t * 40.0)
				draw_texture_rect(_flash_tex, rect, false, Color(1, 1, 1, clampf(fl, 0, 1)))
			else:
				draw_texture_rect(tex, Rect2(p, Vector2(CELL, CELL)), false)
	# lock flashes
	for f in _lock_flash:
		var a: float = 0.7 * (1.0 - f["t"] / 0.22)
		for c: Vector2i in f["cells"]:
			if c.y >= HID - SHOW_ABOVE:
				draw_texture_rect(_flash_tex, Rect2(cell_pos(c), Vector2(CELL, CELL)), false, Color(1, 1, 1, a))
	if engine.state != TetrisEngine.State.FALLING or engine.active_type == 0:
		return
	var col := Tetromino.color(engine.active_type)
	# ghost
	if ghost_enabled:
		var gp := engine.ghost_pos()
		if gp != engine.active_pos:
			for c: Vector2i in Tetromino.cells(engine.active_type, engine.active_rot):
				var cc := gp + c
				if cc.y >= HID:
					draw_texture_rect(_ghost_tex, Rect2(cell_pos(cc), Vector2(CELL, CELL)), false,
						Color(col.r * 0.6 + 0.4, col.g * 0.6 + 0.4, col.b * 0.6 + 0.4, 0.9))
	# active piece
	var tex_a: Texture2D = _tex[engine.active_type]
	var bounce := -sin(_piece_bounce * PI) * 3.0
	for c: Vector2i in engine.active_cells():
		if c.y >= HID - SHOW_ABOVE:
			draw_texture_rect(tex_a, Rect2(cell_pos(c) + Vector2(0, bounce), Vector2(CELL, CELL)), false)
	# lock delay hint: the piece slowly whitens while it rests
	if engine._on_ground:
		var k := clampf(engine._lock_timer / engine.rules.lock_delay, 0.0, 1.0)
		for c: Vector2i in engine.active_cells():
			if c.y >= HID - SHOW_ABOVE:
				draw_texture_rect(_flash_tex, Rect2(cell_pos(c), Vector2(CELL, CELL)), false, Color(1, 1, 1, 0.28 * k))
