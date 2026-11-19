extends TestBase
## Core rules: spawning, movement, collisions, SRS, locking, clears, scoring.

const T := Tetromino.Type


func test_spawn_positions() -> void:
	for type: int in Tetromino.TYPES:
		var e := make_engine()
		e.begin()
		e._spawn(type)
		var xs := []
		var min_y := 99
		var max_y := -1
		for c: Vector2i in e.active_cells():
			xs.append(c.x)
			min_y = mini(min_y, c.y)
			max_y = maxi(max_y, c.y)
		xs.sort()
		var name: String = Tetromino.NAMES[type]
		match type:
			T.I: eq(xs, [3, 4, 5, 6], "I spawn columns")
			T.O: eq(xs, [4, 4, 5, 5], "O spawn columns")
			_: eq([xs[0], xs[-1]], [3, 5], name + " spawn columns")
		# the piece dropped one row: its lowest row is the top visible row
		eq(max_y, TetrisEngine.HIDDEN, name + " lowest row visible after spawn")


func test_rotation_shapes() -> void:
	# T pointing right in state R, pointing down in state 2
	eq(Tetromino.cells(T.T, 1), [Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)], "T state R")
	eq(Tetromino.cells(T.T, 2), [Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)], "T state 2")
	eq(Tetromino.cells(T.I, 1), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)], "I state R")
	eq(Tetromino.cells(T.O, 1), Tetromino.cells(T.O, 0), "O does not change")
	for type: int in Tetromino.TYPES:
		eq(Tetromino.cells(type, 4), Tetromino.cells(type, 0), "4 rotations = identity")


func test_move_and_walls() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.T)
	var n := 0
	while e.move(-1):
		n += 1
	eq(n, 3, "T moves 3 cells left from spawn")
	check(not e.move(-1), "blocked by left wall")
	n = 0
	while e.move(1):
		n += 1
	eq(n, 7, "T crosses to the right wall")
	# blocks stop lateral movement too
	e._spawn(T.O)
	e.set_cell(3, e.active_pos.y, 8)
	check(not e.move(-1), "blocked by a block on the left")


func test_hard_drop_and_lock() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.O)
	var before := e.score
	e.hard_drop()
	eq(e.get_cell(4, 39), T.O, "O landed on the floor")
	eq(e.get_cell(5, 38), T.O, "O landed on the floor (top)")
	eq(e.score - before, 2 * 19, "hard drop = 2 points per row")
	eq(e.pieces, 1, "piece counted")
	check(e.active_type != 0, "next piece spawned")


func test_ghost() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.I)
	var g := e.ghost_cells()
	for c: Vector2i in g:
		eq(c.y, 39, "ghost of flat I on the floor")
	fill_rows(e, ["##########", "##########"])
	for c: Vector2i in e.ghost_cells():
		eq(c.y, 37, "ghost sits on the stack")


func test_wall_kick_I() -> void:
	var e := make_engine()
	e.begin()
	force_piece(e, T.I, Vector2i(-2, 30), 1)   # vertical I against the left wall
	check(e.can_place(e.active_pos, 1), "vertical I fits at the wall")
	var ok := e.rotate(1)
	check(ok, "I rotates at the wall thanks to a kick")
	eq(e.active_rot, 2, "I now in state 2")
	var xs := []
	for c: Vector2i in e.active_cells():
		xs.append(c.x)
	xs.sort()
	eq(xs, [0, 1, 2, 3], "kicked I stays inside the board")


func test_tspin_double() -> void:
	var e := make_engine()
	e.begin()
	fill_rows(e, [
		"...#......",
		"###...####",
		"####.#####",
	])
	force_piece(e, T.T, Vector2i(3, 37), 0)
	check(e.rotate(1), "T rotates into R")
	check(e.rotate(1), "T rotates into 2 (in the slot)")
	eq(e.detect_tspin(), TetrisEngine.TSpin.FULL, "T-spin detected")
	var got := {}
	e.lines_cleared.connect(func(rows, res): got.merge(res, true))
	var before := e.score
	e._lock_piece()
	eq(got.get("lines", 0), 2, "T-spin double clears 2 lines")
	eq(e.score - before, 1200, "T-spin double = 1200 at level 1")
	eq(row_text(e, 39), "...#......", "overhang fell to the bottom")


func test_tspin_mini_detection() -> void:
	var e := make_engine()
	e.begin()
	force_piece(e, T.T, Vector2i(0, 38), 0)
	e.set_cell(0, 38, 8)
	e._last_was_rotation = true
	e._last_kick = 0
	eq(e.detect_tspin(), TetrisEngine.TSpin.MINI, "3 corners, one front corner = mini")
	e._last_kick = 4
	eq(e.detect_tspin(), TetrisEngine.TSpin.FULL, "5th kick upgrades to full")
	e._last_was_rotation = false
	eq(e.detect_tspin(), TetrisEngine.TSpin.NONE, "no rotation = no T-spin")


func test_line_clears_and_scores() -> void:
	var expected := {1: 100, 2: 300, 3: 500, 4: 800}
	for n: int in expected.keys():
		var e := make_engine()
		e.begin()
		var rows := []
		for i in n:
			rows.append("#########.")
		fill_rows(e, rows)
		force_piece(e, T.I, Vector2i(7, 30), 1)   # vertical I in column 9
		var got := {}
		e.lines_cleared.connect(func(r, res): got.merge(res, true))
		e.hard_drop()
		eq(got.get("lines", 0), n, "%d lines cleared" % n)
		# 4 rows: the I empties the board = perfect clear bonus (2000)
		var pc := 2000 if n == 4 else 0
		eq(e.score, expected[n] + pc + 12, "score for %d lines (+6 rows hard drop)" % n)
		eq(e.lines, n, "line counter")
		eq(e.get_cell(0, 39), 0 if n == 4 else 0, "bottom-left empty after clear")


func test_back_to_back_and_combo() -> void:
	var e := make_engine()
	e.begin()
	fill_rows(e, [
		"#########.", "#########.", "#########.", "#########.",
		"#########.", "#########.", "#########.", "#########.",
		"####.#####",
	])
	force_piece(e, T.I, Vector2i(7, 27), 1)
	e.hard_drop()
	var after_first := e.score
	eq(after_first, 800 + 2 * 8, "first Tetris")
	force_piece(e, T.I, Vector2i(7, 27), 1)
	var res := {}
	e.lines_cleared.connect(func(r, x): res.merge(x, true))
	e.hard_drop()
	check(res.get("b2b", false), "second Tetris is back-to-back")
	# 800*1.5 = 1200, combo 1 = +50, hard drop 2*8
	eq(e.score - after_first, 1200 + 50 + 16, "B2B Tetris + combo score")
	eq(e.combo, 1, "combo counter")
	eq(e.stats["tetrises"], 2, "tetris stat")
	eq(e.stats["perfect_clears"], 0, "no perfect clear here")
	eq(row_text(e, 39), "####.#####", "bottom row untouched")


func test_perfect_clear_single() -> void:
	var e := make_engine()
	e.begin()
	fill_rows(e, ["######...."])
	force_piece(e, T.I, Vector2i(6, 38), 0)
	var res := {}
	e.lines_cleared.connect(func(r, x): res.merge(x, true))
	e.hard_drop()
	check(res.get("perfect", false), "perfect clear detected")
	eq(res.get("points", 0), 100 + 800, "single + perfect clear bonus")


func test_hold() -> void:
	var e := make_engine()
	e.begin()
	var first := e.active_type
	var next: int = e.queue[0]
	check(e.hold(), "first hold works")
	eq(e.hold_type, first, "held piece stored")
	eq(e.active_type, next, "next piece came in")
	check(not e.hold(), "only one hold per piece")
	e.hard_drop()
	var cur := e.active_type
	check(e.hold(), "hold allowed again after lock")
	eq(e.active_type, first, "swapped back the held piece")
	eq(e.hold_type, cur, "current piece now held")
	var e2 := make_engine(GameRules.Mode.MARATHON, {"hold": false})
	e2.begin()
	check(not e2.hold(), "hold can be disabled")


func test_seven_bag() -> void:
	var b := BagRandomizer.new(42)
	for bag in 100:
		var seen := {}
		for i in 7:
			seen[b.next_piece()] = true
		eq(seen.size(), 7, "bag %d contains the 7 pieces" % bag)


func test_gravity_and_lock_delay() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.T)
	var y0 := e.active_pos.y
	e.update(0.5)
	eq(e.active_pos.y, y0, "level 1: no fall before 1 s")
	e.update(0.51)
	eq(e.active_pos.y, y0 + 1, "level 1: one row per second")
	check(absf(e.gravity_interval() - 1.0) < 0.0001, "level 1 interval")
	e.level = 15
	check(absf(e.gravity_interval() - pow(0.8 - 14 * 0.007, 14)) < 1e-6, "level 15 interval (guideline)")
	e.level = 1
	# lock delay: put the piece on the floor then wait
	var p := e.ghost_pos()
	e.active_pos = p
	e._lowest_y = p.y
	e.update(0.3)
	eq(e.pieces, 0, "not locked before 0.5 s on the ground")
	e.update(0.25)
	eq(e.pieces, 1, "locked after 0.5 s")


func test_move_reset_limit() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.T)
	var p := e.ghost_pos()
	e.active_pos = p
	e._lowest_y = p.y
	var dir := 1
	# 15 moves each reset the timer...
	for i in 15:
		e.update(0.4)
		if not e.move(dir):
			dir = -dir
			e.move(dir)
	eq(e.pieces, 0, "15 resets keep the piece alive")
	# ...the 16th does not
	e.update(0.2)
	if not e.move(dir):
		e.move(-dir)
	e.update(0.01)
	eq(e.pieces, 1, "piece locks once the 15 resets are used")


func test_soft_drop() -> void:
	var e := make_engine()
	e.begin()
	e._spawn(T.T)
	var y0 := e.active_pos.y
	e.set_soft_drop(true)
	e.update(0.0)
	eq(e.active_pos.y, y0 + 1, "soft drop reacts immediately")
	e.update(0.051)
	eq(e.active_pos.y, y0 + 2, "soft drop = 20x gravity")
	eq(e.score, 2, "1 point per soft-dropped row")
	e.set_soft_drop(false)


func test_block_out_and_lock_out() -> void:
	var e := make_engine()
	e.begin()
	e.hard_drop()
	for x in range(1, 10):
		e.set_cell(x, 19, 8)
		e.set_cell(x, 18, 8)
	e.hard_drop()  # current piece locks; the next spawn overlaps the stack
	check(e.state == TetrisEngine.State.OVER, "block out ends the game")
	eq(e.finish_reason, "topout", "reason is topout")
	# lock out: piece locking entirely in the hidden zone
	var e2 := make_engine()
	e2.begin()
	for y in range(20, 40):
		for x in 10:
			if x != 0:
				e2.set_cell(x, y, 8)
	force_piece(e2, T.O, Vector2i(4, 17))
	e2.hard_drop()
	eq(e2.finish_reason, "topout", "lock out ends the game")


func test_rows_collapse_with_delay() -> void:
	var e := make_engine()
	e.rules.line_clear_delay = 0.3
	e.begin()
	fill_rows(e, ["#.########", "##.#######"])
	force_piece(e, T.I, Vector2i(0, 36), 1)
	e.active_pos = Vector2i(-1, 35)
	e.hard_drop()
	eq(e.state, TetrisEngine.State.CLEARING, "clearing state during the delay")
	e.update(0.31)
	eq(e.state, TetrisEngine.State.FALLING, "next piece after the delay")
	eq(row_text(e, 39), "##.#######", "cleared row removed, the other one fell")


func test_random_bot_invariants() -> void:
	var e := make_engine(GameRules.Mode.ENDLESS, {"seed": 7})
	e.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var games := 0
	var placed := 0
	for step in 40000:
		if e.state == TetrisEngine.State.OVER:
			games += 1
			e.rules.rng_seed = rng.randi() % 100000
			e.reset()
			e.begin()
		var r := rng.randi() % 10
		match r:
			0, 1: e.move(-1)
			2, 3: e.move(1)
			4: e.rotate(1)
			5: e.rotate(-1)
			6: e.hold()
			7:
				e.hard_drop()
				placed += 1
			_: e.update(1.0 / 60.0)
		# invariants: active piece never overlaps the stack
		if e.state == TetrisEngine.State.FALLING and e.active_type != 0:
			if not e.can_place(e.active_pos, e.active_rot):
				check(false, "active piece overlaps stack at step %d" % step)
				return
	for v in e.board:
		check(v <= 8, "board values valid")
	check(placed > 1000, "bot placed pieces (%d), games %d" % [placed, games])
