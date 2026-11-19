extends TestBase
## Modes only change goals and starting parameters.

const T := Tetromino.Type


func _tetris(e: TetrisEngine) -> void:
	fill_rows(e, ["#########.", "#########.", "#########.", "#########."])
	force_piece(e, T.I, Vector2i(7, 30), 1)
	e.hard_drop()
	e.update(0.0)


func test_sprint_goal() -> void:
	var e := make_engine(GameRules.Mode.SPRINT)
	eq(e.rules.line_goal, 40, "sprint goal")
	check(not e.rules.level_progression, "sprint keeps level 1")
	e.begin()
	e.update(12.5)
	e.lines = 36
	var reasons := []
	e.finished.connect(func(r): reasons.append(r))
	_tetris(e)
	eq(e.lines, 40, "40 lines")
	eq(e.level, 1, "sprint level stays 1")
	eq(reasons, ["goal"], "sprint finished with goal")
	check(e.is_clear(), "sprint counts as cleared")
	var t := e.time
	e.update(5.0)
	eq(e.time, t, "timer frozen after the goal")


func test_ultra_time_limit() -> void:
	var e := make_engine(GameRules.Mode.ULTRA)
	eq(e.rules.time_limit, 180.0, "ultra lasts 3 minutes")
	e.begin()
	var reasons := []
	e.finished.connect(func(r): reasons.append(r))
	for i in 179:
		e.update(1.0)
		if e.state == TetrisEngine.State.OVER:
			break
		if e.active_type != 0:
			e.hard_drop()
		if e.state == TetrisEngine.State.OVER:
			break
	if e.state != TetrisEngine.State.OVER:
		e.update(1.5)
	check(reasons.size() == 1, "ultra finished once")
	if reasons.size() == 1 and reasons[0] == "time":
		check(absf(e.time - 180.0) < 0.001, "clock stops at 3:00")
		eq(e.time_left(), 0.0, "no time left")


func test_marathon_levels_and_goal() -> void:
	var e := make_engine(GameRules.Mode.MARATHON, {"start_level": 1})
	e.begin()
	var levels := []
	e.level_changed.connect(func(l): levels.append(l))
	_tetris(e)
	_tetris(e)
	_tetris(e)
	eq(e.lines, 12, "12 lines")
	eq(e.level, 2, "level 2 after 10 lines")
	eq(levels, [2], "one level up signal")
	e.lines = 146
	var reasons := []
	e.finished.connect(func(r): reasons.append(r))
	_tetris(e)
	eq(e.level, 15, "level capped at 15")
	eq(reasons, ["goal"], "marathon ends at 150 lines")


func test_marathon_start_level() -> void:
	var e := make_engine(GameRules.Mode.MARATHON, {"start_level": 8})
	eq(e.level, 8, "start level honoured")
	e.begin()
	_tetris(e)
	_tetris(e)
	_tetris(e)
	eq(e.level, 9, "10 lines later: level 9")


func test_endless_has_no_goal() -> void:
	var e := make_engine(GameRules.Mode.ENDLESS)
	eq(e.rules.line_goal, 0, "no line goal")
	eq(e.rules.time_limit, 0.0, "no time limit")
	e.begin()
	e.lines = 196
	_tetris(e)
	eq(e.level, 21, "levels keep rising past 15")
	check(e.state != TetrisEngine.State.OVER, "still playing")
	check(e.gravity_interval() <= pow(0.8 - 19 * 0.007, 19) + 1e-9, "gravity capped at level 20")


func test_practice() -> void:
	var e := make_engine(GameRules.Mode.PRACTICE, {"start_level": 5, "gravity": false})
	check(not e.rules.save_records, "practice saves no record")
	eq(e.level, 5, "practice level")
	e.begin()
	var y := e.active_pos.y
	e.update(30.0)
	eq(e.active_pos.y, y, "no gravity in practice when disabled")
	_tetris(e)
	_tetris(e)
	_tetris(e)
	eq(e.level, 5, "practice level fixed by default")


func test_same_rules_everywhere() -> void:
	# every mode shares the core Tetris parameters
	for m in 5:
		var r := GameRules.for_mode(m)
		eq(r.lock_delay, 0.5, "lock delay mode %d" % m)
		eq(r.max_lock_resets, 15, "move reset mode %d" % m)
		eq(r.lines_per_level, 10, "10 lines per level mode %d" % m)
		eq(r.next_count, 5, "next queue mode %d" % m)
