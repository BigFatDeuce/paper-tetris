class_name TetrisEngine
extends RefCounted
## Pure Tetris logic: board, active piece, SRS rotation, gravity, lock delay,
## line clears, guideline scoring and goals. No rendering, no input devices:
## the game scene drives it with update(dt) and commands, and listens to the
## signals. Grid: x right, y DOWN. Rows 0..19 are the hidden buffer above the
## 20 visible rows (20..39).

signal piece_spawned(type: int)
signal piece_moved(dx: int)
signal piece_rotated(dir: int, kick: int)
signal piece_landed()
signal soft_dropped(rows: int)
signal hard_dropped(rows: int, cells: Array)
signal piece_locked(cells: Array, type: int, tspin: int)
signal lines_cleared(rows: Array, result: Dictionary)
signal rows_collapsed(rows: Array)
signal hold_used(type: int)
signal queue_changed()
signal level_changed(level: int)
signal goal_reached()
signal finished(reason: String)
signal danger_changed(on: bool)

const WIDTH := 10
const HEIGHT := 40
const VISIBLE := 20
const HIDDEN := HEIGHT - VISIBLE
const DANGER_ROWS := 16   # stack height that makes the crowd nervous

enum State { READY, FALLING, CLEARING, ENTRY, OVER }
enum TSpin { NONE, MINI, FULL }

const LINE_SCORES := [0, 100, 300, 500, 800]
const TSPIN_SCORES := [400, 800, 1200, 1600]
const TSPIN_MINI_SCORES := [100, 200, 400]
const PERFECT_SCORES := [0, 800, 1200, 1800, 2000]

var rules: GameRules
var board := PackedByteArray()
var state: int = State.READY
var active_type := 0
var active_rot := 0
var active_pos := Vector2i.ZERO
var hold_type := 0
var hold_locked := false
var queue: Array[int] = []
var score := 0
var lines := 0
var level := 1
var combo := -1
var back_to_back := false
var time := 0.0
var pieces := 0
var finish_reason := ""
var goal_hit := false
var danger := false
var stats := {}

var _rand: BagRandomizer
var _gravity_acc := 0.0
var _lock_timer := 0.0
var _lock_resets := 0
var _lowest_y := 0
var _on_ground := false
var _soft_drop := false
var _last_was_rotation := false
var _last_kick := 0
var _state_timer := 0.0
var _clearing_rows: Array = []


func _init(game_rules: GameRules = null) -> void:
	rules = game_rules if game_rules else GameRules.for_mode(GameRules.Mode.MARATHON)
	reset()


func reset() -> void:
	board = PackedByteArray()
	board.resize(WIDTH * HEIGHT)
	board.fill(0)
	_rand = BagRandomizer.new(rules.rng_seed)
	queue.clear()
	for i in rules.next_count + 1:
		queue.append(_rand.next_piece())
	state = State.READY
	active_type = 0
	hold_type = 0
	hold_locked = false
	score = 0
	lines = 0
	level = rules.start_level
	combo = -1
	back_to_back = false
	time = 0.0
	pieces = 0
	finish_reason = ""
	goal_hit = false
	danger = false
	stats = {
		"singles": 0, "doubles": 0, "triples": 0, "tetrises": 0,
		"tspins": 0, "tspin_minis": 0, "perfect_clears": 0,
		"max_combo": 0, "b2b": 0,
	}
	_soft_drop = false


## Starts play (called after the countdown).
func begin() -> void:
	if state == State.READY:
		_spawn_next()


# --------------------------------------------------------------------- board

func get_cell(x: int, y: int) -> int:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return 255
	return board[y * WIDTH + x]


func set_cell(x: int, y: int, v: int) -> void:
	board[y * WIDTH + x] = v


func is_free(x: int, y: int) -> bool:
	return get_cell(x, y) == 0


func can_place(pos: Vector2i, rot: int, type: int = -1) -> bool:
	var t := active_type if type < 0 else type
	for c: Vector2i in Tetromino.cells(t, rot):
		if not is_free(pos.x + c.x, pos.y + c.y):
			return false
	return true


func active_cells() -> Array:
	var out: Array = []
	if active_type == 0:
		return out
	for c: Vector2i in Tetromino.cells(active_type, active_rot):
		out.append(active_pos + c)
	return out


func ghost_pos() -> Vector2i:
	var p := active_pos
	while can_place(p + Vector2i.DOWN, active_rot):
		p.y += 1
	return p


func ghost_cells() -> Array:
	var out: Array = []
	if active_type == 0:
		return out
	var p := ghost_pos()
	for c: Vector2i in Tetromino.cells(active_type, active_rot):
		out.append(p + c)
	return out


func stack_height() -> int:
	for y in HEIGHT:
		for x in WIDTH:
			if board[y * WIDTH + x] != 0:
				return HEIGHT - y
	return 0


func is_playing() -> bool:
	return state == State.FALLING or state == State.CLEARING or state == State.ENTRY


# --------------------------------------------------------------------- timing

func gravity_interval() -> float:
	if not rules.gravity_enabled:
		return INF
	var lv := clampi(level, 1, 20)
	return pow(0.8 - (lv - 1) * 0.007, lv - 1)


func soft_drop_interval() -> float:
	var g := gravity_interval()
	if is_inf(g):
		g = 1.0
	return g / rules.soft_drop_factor


func time_left() -> float:
	return maxf(rules.time_limit - time, 0.0) if rules.time_limit > 0.0 else 0.0


func update(dt: float) -> void:
	if state == State.READY or state == State.OVER:
		return
	if not goal_hit:
		time += dt
		if rules.time_limit > 0.0 and time >= rules.time_limit:
			time = rules.time_limit
			_finish("time")
			return
	match state:
		State.FALLING:
			_update_falling(dt)
		State.CLEARING:
			_state_timer -= dt
			if _state_timer <= 0.0:
				_collapse_rows()
		State.ENTRY:
			_state_timer -= dt
			if _state_timer <= 0.0:
				_spawn_next()


func _update_falling(dt: float) -> void:
	var interval := soft_drop_interval() if _soft_drop else gravity_interval()
	if _soft_drop:
		interval = minf(interval, gravity_interval())
	if not is_inf(interval):
		_gravity_acc += dt
		var steps := 0
		while _gravity_acc >= interval and steps < HEIGHT:
			steps += 1
			if can_place(active_pos + Vector2i.DOWN, active_rot):
				_gravity_acc -= interval
				active_pos.y += 1
				_last_was_rotation = false
				if _soft_drop:
					score += 1
					soft_dropped.emit(1)
				_on_descended()
			else:
				_gravity_acc = 0.0
				break
	if _is_grounded():
		if not _on_ground:
			_on_ground = true
			piece_landed.emit()
		_lock_timer += dt
		if _lock_timer >= rules.lock_delay or _lock_resets > rules.max_lock_resets:
			_lock_piece()
	else:
		_on_ground = false


func _is_grounded() -> bool:
	return not can_place(active_pos + Vector2i.DOWN, active_rot)


func _on_descended() -> void:
	if active_pos.y > _lowest_y:
		_lowest_y = active_pos.y
		_lock_resets = 0
		_lock_timer = 0.0


func _after_shift(was_grounded: bool) -> void:
	if was_grounded or _is_grounded():
		if _lock_resets < rules.max_lock_resets:
			_lock_timer = 0.0
		_lock_resets += 1
	if not _is_grounded():
		_on_ground = false


# ------------------------------------------------------------------- commands

func move(dx: int) -> bool:
	if state != State.FALLING:
		return false
	var grounded := _is_grounded()
	var p := active_pos + Vector2i(dx, 0)
	if not can_place(p, active_rot):
		return false
	active_pos = p
	_last_was_rotation = false
	_after_shift(grounded)
	piece_moved.emit(dx)
	return true


## dir: +1 clockwise, -1 counter-clockwise.
func rotate(dir: int) -> bool:
	if state != State.FALLING:
		return false
	var to := posmod(active_rot + dir, 4)
	var grounded := _is_grounded()
	var ks := Tetromino.kicks(active_type, active_rot, to)
	for i in ks.size():
		var p: Vector2i = active_pos + ks[i]
		if can_place(p, to):
			active_pos = p
			active_rot = to
			_last_was_rotation = true
			_last_kick = i
			_on_descended()
			_after_shift(grounded)
			piece_rotated.emit(dir, i)
			return true
	return false


func set_soft_drop(on: bool) -> void:
	if on and not _soft_drop and state == State.FALLING:
		# react immediately to the key press
		_gravity_acc = maxf(_gravity_acc, soft_drop_interval())
	_soft_drop = on


func hard_drop() -> void:
	if state != State.FALLING:
		return
	var d := 0
	while can_place(active_pos + Vector2i.DOWN, active_rot):
		active_pos.y += 1
		d += 1
	if d > 0:
		_last_was_rotation = false
	score += 2 * d
	hard_dropped.emit(d, active_cells())
	_lock_piece()


func hold() -> bool:
	if not rules.hold_enabled or hold_locked or state != State.FALLING:
		return false
	var current := active_type
	if hold_type == 0:
		hold_type = current
		hold_locked = true
		hold_used.emit(hold_type)
		_spawn_next()
	else:
		var h := hold_type
		hold_type = current
		hold_locked = true
		hold_used.emit(hold_type)
		_spawn(h)
	return true


# ---------------------------------------------------------------- lifecycle

func _spawn_next() -> void:
	var t: int = queue.pop_front()
	queue.append(_rand.next_piece())
	queue_changed.emit()
	_spawn(t)


func _spawn(type: int) -> void:
	active_type = type
	active_rot = 0
	active_pos = Vector2i(Tetromino.spawn_x(type, WIDTH), HIDDEN - 2)
	_gravity_acc = 0.0
	_lock_timer = 0.0
	_lock_resets = 0
	_on_ground = false
	_last_was_rotation = false
	_last_kick = 0
	if not can_place(active_pos, active_rot):
		state = State.FALLING
		piece_spawned.emit(type)
		_finish("topout")   # block out
		return
	if can_place(active_pos + Vector2i.DOWN, active_rot):
		active_pos.y += 1
	_lowest_y = active_pos.y
	state = State.FALLING
	piece_spawned.emit(type)


func detect_tspin() -> int:
	if active_type != Tetromino.Type.T or not _last_was_rotation:
		return TSpin.NONE
	var c := active_pos + Vector2i(1, 1)
	var corners := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]  # TL TR BR BL
	var filled: Array = []
	var count := 0
	for o: Vector2i in corners:
		var f := not is_free(c.x + o.x, c.y + o.y)
		filled.append(f)
		if f:
			count += 1
	if count < 3:
		return TSpin.NONE
	# the two corners on the side the T points to
	var front: Array = [[0, 1], [1, 2], [2, 3], [3, 0]][active_rot]
	if filled[front[0]] and filled[front[1]]:
		return TSpin.FULL
	if _last_kick == 4:
		return TSpin.FULL
	return TSpin.MINI


func _lock_piece() -> void:
	var cells := active_cells()
	var tspin := detect_tspin()
	var all_hidden := true
	for c: Vector2i in cells:
		set_cell(c.x, c.y, active_type)
		if c.y >= HIDDEN:
			all_hidden = false
	var locked_type := active_type
	active_type = 0
	pieces += 1
	hold_locked = false
	piece_locked.emit(cells, locked_type, tspin)
	if all_hidden:
		_finish("topout")   # lock out
		return
	var rows := _full_rows()
	var result := _score(rows.size(), tspin, rows)
	if rows.is_empty():
		_update_danger()
		if result["points"] > 0:
			lines_cleared.emit(rows, result)
		state = State.ENTRY
		_state_timer = rules.entry_delay
		if _state_timer <= 0.0:
			_spawn_next()
		return
	_clearing_rows = rows
	state = State.CLEARING
	_state_timer = rules.line_clear_delay
	lines_cleared.emit(rows, result)
	if goal_hit:
		goal_reached.emit()
	if _state_timer <= 0.0:
		_collapse_rows()


func _full_rows() -> Array:
	var rows: Array = []
	for y in HEIGHT:
		var full := true
		for x in WIDTH:
			if board[y * WIDTH + x] == 0:
				full = false
				break
		if full:
			rows.append(y)
	return rows


func _score(n: int, tspin: int, rows: Array) -> Dictionary:
	var lv := level
	var base := 0
	var difficult := false
	match tspin:
		TSpin.FULL:
			base = TSPIN_SCORES[mini(n, 3)]
			difficult = n > 0
		TSpin.MINI:
			base = TSPIN_MINI_SCORES[mini(n, 2)]
			difficult = n > 0
		_:
			base = LINE_SCORES[mini(n, 4)]
			difficult = n == 4
	var b2b_bonus := false
	if n > 0:
		if difficult:
			if back_to_back:
				base = base * 3 / 2
				b2b_bonus = true
				stats["b2b"] += 1
			back_to_back = true
		else:
			back_to_back = false
	var points := base * lv
	if n > 0:
		combo += 1
		if combo > 0:
			points += 50 * combo * lv
		stats["max_combo"] = maxi(stats["max_combo"], combo)
	else:
		combo = -1
	# perfect clear: board empty once the rows are gone
	var perfect := false
	if n > 0:
		perfect = true
		for y in HEIGHT:
			if rows.has(y):
				continue
			for x in WIDTH:
				if board[y * WIDTH + x] != 0:
					perfect = false
					break
			if not perfect:
				break
		if perfect:
			var pc: int = PERFECT_SCORES[mini(n, 4)]
			if n == 4 and b2b_bonus:
				pc = 3200
			points += pc * lv
			stats["perfect_clears"] += 1
	score += points
	match n:
		1: stats["singles"] += 1
		2: stats["doubles"] += 1
		3: stats["triples"] += 1
		4: stats["tetrises"] += 1
	if tspin == TSpin.FULL and n > 0:
		stats["tspins"] += 1
	elif tspin == TSpin.MINI and n > 0:
		stats["tspin_minis"] += 1
	var old_level := level
	lines += n
	if rules.level_progression and n > 0:
		@warning_ignore("integer_division")
		level = mini(rules.start_level + lines / rules.lines_per_level, rules.max_level)
	if rules.line_goal > 0 and lines >= rules.line_goal and not goal_hit:
		goal_hit = true
	var res := {
		"lines": n, "tspin": tspin, "b2b": b2b_bonus, "combo": combo,
		"perfect": perfect, "points": points, "level": lv,
	}
	if level != old_level:
		level_changed.emit(level)
	return res


func _collapse_rows() -> void:
	var rows := _clearing_rows.duplicate()
	rows.sort()
	for r: int in rows:
		# shift everything above r down by one
		for y in range(r, 0, -1):
			for x in WIDTH:
				board[y * WIDTH + x] = board[(y - 1) * WIDTH + x]
		for x in WIDTH:
			board[x] = 0
	_clearing_rows = []
	rows_collapsed.emit(rows)
	_update_danger()
	if goal_hit:
		_finish("goal")
		return
	state = State.ENTRY
	_state_timer = rules.entry_delay
	if _state_timer <= 0.0:
		_spawn_next()


func _update_danger() -> void:
	var d := stack_height() >= DANGER_ROWS
	if d != danger:
		danger = d
		danger_changed.emit(d)


func _finish(reason: String) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	finish_reason = reason
	_soft_drop = false
	finished.emit(reason)


## True when the game ended "successfully" (goal or time limit reached).
func is_clear() -> bool:
	return finish_reason == "goal" or finish_reason == "time"


func pieces_per_second() -> float:
	return pieces / time if time > 0.01 else 0.0
