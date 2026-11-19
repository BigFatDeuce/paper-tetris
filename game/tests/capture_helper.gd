extends Node
## See capture.gd. Saves screenshots at the requested times and can drive a
## scripted demo in the game scene (fills the board, clears lines...).

var args := {}
var _t := 0.0
var _shots: Array = []
var _shot_i := 0
var _quit_at := 0.0
var _demo_done := false
var _bot_t := 0.0
var _frames := 0
var _fps_acc := 0.0
var _inputs: Array = []   # [[time, action], ...]
var _release: Array = []
# smart bot: a planned move played out one input at a time, like a person
var _plan := {}
var _plan_piece := -1
var _step_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in str(args.get("shots", "3")).split(","):
		_shots.append(float(s))
	_quit_at = float(args.get("quit", str(float(_shots[-1]) + 0.5)))
	if args.has("inputs"):
		for part in str(args["inputs"]).split(","):
			var kv := part.split(":")
			if kv.size() == 2:
				_inputs.append([float(kv[0]), kv[1]])


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_fps_acc += delta
	var scene := get_tree().current_scene
	if args.get("demo", "0") != "0" and scene and scene.get("engine") != null and not _demo_done:
		var e: TetrisEngine = scene.engine
		if e.state == TetrisEngine.State.FALLING:
			_demo_done = true
			_setup_demo(e)
	if scene and scene.get("engine") != null:
		match str(args.get("bot", "0")):
			"1": _bot(scene.engine, delta)
			"smart": _smart_bot(scene.engine, delta)
	# scripted input: press an action, release it 0.08 s later
	for r in _release.duplicate():
		if _t >= r[0]:
			var up := InputEventAction.new()
			up.action = r[1]
			up.pressed = false
			Input.parse_input_event(up)
			_release.erase(r)
	while not _inputs.is_empty() and _t >= float(_inputs[0][0]):
		var it: Array = _inputs.pop_front()
		if str(it[1]).begins_with("tap@"):
			# tap@X;Y[;seconds]: a finger on the screen (viewport pixels)
			var p := str(it[1]).substr(4).split(";")
			var pos := Vector2(float(p[0]), float(p[1])) * Vector2(DisplayServer.window_get_size()) / Vector2(1920, 1080)
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = pos
			t.pressed = true
			Input.parse_input_event(t)
			var hold := float(p[2]) if p.size() > 2 else 0.12
			get_tree().create_timer(hold, true, false, true).timeout.connect(func():
				var u := InputEventScreenTouch.new()
				u.index = 0
				u.position = pos
				u.pressed = false
				Input.parse_input_event(u))
			print("CAPTURE tap ", pos, " at ", snappedf(_t, 0.01))
			continue
		if str(it[1]).begins_with("joy@") or str(it[1]).begins_with("axis@"):
			# joy@BUTTON: a real gamepad button press; axis@AXIS;VALUE: a stick
			_pad_input(str(it[1]))
			continue
		var ev := InputEventAction.new()
		ev.action = it[1]
		ev.pressed = true
		Input.parse_input_event(ev)
		_release.append([_t + 0.08, it[1]])
		print("CAPTURE input ", it[1], " at ", snappedf(_t, 0.01))
	if _shot_i < _shots.size() and _t >= float(_shots[_shot_i]):
		var path := "%s_%d.png" % [str(args.get("out", "user://shot")), _shot_i]
		var img := get_viewport().get_texture().get_image()
		_shot_i += 1
		if img == null:
			return
		img.save_png(path)
		_shot_i -= 1
		print("CAPTURE saved ", path, " at ", snappedf(_t, 0.01), "s fps=", Engine.get_frames_per_second(),
			" process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" objects=", Performance.get_monitor(Performance.OBJECT_COUNT),
			" nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_shot_i += 1
	if _t >= _quit_at:
		print("CAPTURE avg fps ", snappedf(_frames / maxf(_fps_acc, 0.001), 0.1))
		get_tree().quit()


func _setup_demo(e: TetrisEngine) -> void:
	match str(args.get("demo", "1")):
		"well": return _demo_rows(e, _well_rows(), 1, 61340, 52, 6)
		"perfect": return _demo_rows(e, ["JJJLLOOZZ.", "TJLLLOOSZ.", "TTSSIIIIZ.", "TZZSSOOLL."], 1, 88020, 76, 8, true)
		"danger": return _demo_rows(e, [
			"..T....O..", ".TTL..OOS.", "JJ.LL.ZSS.", "J.ILLZZ.SO", "J.I.OO.TTO", "ZZI.OOJ.T.",
			"SZZ.LJJJ.I", "SS.LLL.OOI", ".ZZJ.TOO.I", "ZZ.JJTT.LI", "IIII.T.LLL", "SS.ZZ.OOJ.",
			"OOSS.ZZ.JJ", "OO.LLL.TTT", "IIII.SSOO.", "JJJ.LLL.OO"], 0, 120480, 98, 9)
	# a believable mid-game stack with a well on the right
	var rows := [
		"LLJJ.ZZSSI", "LJJJ.ZSSOI", "TTTOO.SSOI", "ITTOOZZ.JI",
		"I.SSZZLLJJ", "ISS.ZZLJJJ",
	]
	var map := {"I": 1, "O": 2, "T": 3, "S": 4, "Z": 5, "J": 6, "L": 7}
	for i in rows.size():
		var y := TetrisEngine.HEIGHT - rows.size() + i
		for x in TetrisEngine.WIDTH:
			var ch: String = rows[i][x]
			e.set_cell(x, y, map.get(ch, 0))
	e.score = 48250
	e.lines = 37
	e.level = 4


## A clean stack with the right column left open (varies with the stage).
func _well_rows() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(args.get("stage", "toybox")))
	var letters := "IOTSZJL"
	var rows := []
	var tops := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for x in 9:
		tops[x] = r.randi_range(0, 2)
	for y in 3:
		var row := ""
		for x in 9:
			row += letters[r.randi_range(0, 6)] if tops[x] > 2 - y - 1 else "."
		rows.append(row + ".")
	for y in 4:
		var row := ""
		for x in 9:
			row += letters[r.randi_range(0, 6)]
		rows.append(row + ".")
	return rows


func _demo_rows(e: TetrisEngine, rows: Array, next_i: int, score: int, lines: int, level: int, spawn_i := false) -> void:
	var map := {"I": 1, "O": 2, "T": 3, "S": 4, "Z": 5, "J": 6, "L": 7}
	for i in rows.size():
		var y := TetrisEngine.HEIGHT - rows.size() + i
		for x in TetrisEngine.WIDTH:
			e.set_cell(x, y, map.get(rows[i][x], 0))
	e.score = score
	e.lines = lines
	e.level = level
	if next_i > 0:
		e.queue[0] = Tetromino.Type.I
		e.queue_changed.emit()
	if spawn_i:
		e._spawn(Tetromino.Type.I)
	# let the board view pick up the new cells
	if e.has_signal("rows_collapsed"):
		e.rows_collapsed.emit([])


func _bot(e: TetrisEngine, delta: float) -> void:
	# naive bot: random column / rotation, hard drop every 0.35 s
	if e.state != TetrisEngine.State.FALLING:
		return
	_bot_t += delta
	if _bot_t < float(args.get("bot_rate", "0.35")):
		return
	_bot_t = 0.0
	var best_x := 0
	var best_r := 0
	var best_score := -1e9
	for r in 4:
		for x in range(-2, TetrisEngine.WIDTH):
			var p := Vector2i(x, e.active_pos.y)
			if not e.can_place(p, r):
				continue
			while e.can_place(p + Vector2i.DOWN, r):
				p.y += 1
			var sc := 0.0
			for c: Vector2i in Tetromino.cells(e.active_type, r):
				sc += (p.y + c.y) * 1.0
			sc += randf() * 2.0
			if sc > best_score:
				best_score = sc
				best_x = x
				best_r = r
	for i in best_r:
		e.rotate(1)
	var dx := best_x - e.active_pos.x
	for i in absi(dx):
		e.move(signi(dx))
	e.hard_drop()


# ------------------------------------------------------------ showcase bot
## Plays a clean game for trailers: keeps the right column open as a well,
## stacks flat and fires Tetrises. Inputs are played one by one (rotate,
## shift, short pause, hard drop) so the footage looks like a real player.
func _smart_bot(e: TetrisEngine, delta: float) -> void:
	if e.state != TetrisEngine.State.FALLING:
		_plan_piece = -1
		return
	var speed := float(args.get("bot_speed", "1.0"))
	_step_t += delta * speed
	if _plan_piece != e.pieces or _plan.is_empty():
		if _plan_piece == e.pieces and _plan.is_empty():
			return
		_plan_piece = e.pieces
		_step_t = -0.10
		_plan = _best_plan(e)
		if _plan.get("hold", false):
			_plan = {}
			e.hold()
			_plan_piece = -1
			return
	if _step_t < 0.045:
		return
	_step_t = 0.0
	var want_r: int = _plan["r"]
	if e.active_rot != want_r:
		e.rotate(-1 if (want_r - e.active_rot + 4) % 4 == 3 else 1)
		return
	var dx: int = int(_plan["x"]) - e.active_pos.x
	if dx != 0:
		if not e.move(signi(dx)):
			_plan["x"] = e.active_pos.x
		return
	if not _plan.get("waited", false):
		_plan["waited"] = true
		_step_t = -0.06
		return
	if args.has("bot_debug") and e.pieces % 10 == 0:
		print("BOT plan r=%d x=%d -> rot=%d x=%d type=%d score=%.1f lines=%d h=%d" % [_plan["r"], _plan["x"], e.active_rot, e.active_pos.x, e.active_type, _plan["score"], e.lines, e.stack_height()])
	e.hard_drop()
	if args.get("bot_debug", "") == "board" and e.pieces % 6 == 0:
		for y in range(TetrisEngine.HEIGHT - 16, TetrisEngine.HEIGHT):
			var row := ""
			for x in TetrisEngine.WIDTH:
				row += "#" if e.get_cell(x, y) != 0 else "."
			print("BOARD ", row)
	_plan = {}


func _best_plan(e: TetrisEngine) -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(TetrisEngine.WIDTH * TetrisEngine.HEIGHT)
	for y in TetrisEngine.HEIGHT:
		for x in TetrisEngine.WIDTH:
			grid[y * TetrisEngine.WIDTH + x] = 1 if e.get_cell(x, y) != 0 else 0
	var cur := _best_for(e, grid, e.active_type)
	if e.rules.hold_enabled and not e.hold_locked:
		var alt_type: int = e.hold_type if e.hold_type != 0 else (e.queue[0] if not e.queue.is_empty() else 0)
		if alt_type != 0 and alt_type != e.active_type:
			var alt := _best_for(e, grid, alt_type)
			if float(alt["score"]) > float(cur["score"]) + 4.0:
				return {"hold": true}
	return cur


func _best_for(e: TetrisEngine, grid: PackedByteArray, type: int) -> Dictionary:
	var best := {"r": 0, "x": e.active_pos.x, "score": -1e9}
	var start_y := e.active_pos.y
	for r in 4:
		for x in range(-3, TetrisEngine.WIDTH + 1):
			var p := Vector2i(x, start_y)
			if not _fits(grid, type, r, p):
				continue
			while _fits(grid, type, r, p + Vector2i.DOWN):
				p.y += 1
			var sc := _evaluate(grid, type, r, p)
			if sc > float(best["score"]):
				best = {"r": r, "x": x, "score": sc}
	return best


func _fits(grid: PackedByteArray, type: int, r: int, p: Vector2i) -> bool:
	for c: Vector2i in Tetromino.cells(type, r):
		var q := p + c
		if q.x < 0 or q.x >= TetrisEngine.WIDTH or q.y >= TetrisEngine.HEIGHT:
			return false
		if q.y >= 0 and grid[q.y * TetrisEngine.WIDTH + q.x] != 0:
			return false
	return true


func _evaluate(grid: PackedByteArray, type: int, r: int, p: Vector2i) -> float:
	var W := TetrisEngine.WIDTH
	var H := TetrisEngine.HEIGHT
	var g := grid.duplicate()
	var in_well := false
	for c: Vector2i in Tetromino.cells(type, r):
		var q := p + c
		if q.y >= 0:
			g[q.y * W + q.x] = 1
		if q.x == W - 1:
			in_well = true
	# clear full rows
	var cleared := 0
	var rows := []
	for y in H:
		var full := true
		for x in W:
			if g[y * W + x] == 0:
				full = false
				break
		if full:
			cleared += 1
		else:
			rows.append(g.slice(y * W, y * W + W))
	var out := PackedByteArray()
	out.resize(W * H)
	var off := (H - rows.size()) * W
	for i in rows.size():
		for x in W:
			out[off + i * W + x] = rows[i][x]
	# features
	var heights := []
	var holes := 0
	for x in W:
		var h := 0
		var seen := false
		for y in H:
			if out[y * W + x] != 0:
				if not seen:
					h = H - y
					seen = true
			elif seen:
				holes += 1
		heights.append(h)
	var agg := 0
	var bump := 0
	var maxh := 0
	for x in W - 1:          # the well column stays out of the flatness score
		agg += heights[x]
		maxh = maxi(maxh, heights[x])
		if x < W - 2:
			bump += absi(heights[x] - heights[x + 1])
	var sc := -0.5 * agg - float(args.get("w_holes", "8")) * holes - 0.4 * bump
	var danger := maxh > int(args.get("w_danger", "7"))
	match cleared:
		4: sc += 50.0
		0: pass
		_: sc += (5.0 * cleared) if danger else (-2.0 * cleared)
	if in_well:
		if cleared == 0:
			sc -= 15.0
		elif cleared < 4 and not danger:
			sc -= 8.0
	sc -= maxf(0, maxh - 10) * 3.0
	return sc + randf() * 0.05


## joy@BUTTON[#DEVICE] / axis@AXIS;VALUE[#DEVICE]
func _pad_input(spec: String) -> void:
	var dev := 0
	if "#" in spec:
		dev = int(spec.get_slice("#", 1))
		spec = spec.get_slice("#", 0)
	if spec.begins_with("joy@"):
		var b := InputEventJoypadButton.new()
		b.device = dev
		b.button_index = int(spec.substr(4)) as JoyButton
		b.pressed = true
		b.pressure = 1.0
		Input.parse_input_event(b)
		get_tree().create_timer(0.08, true, false, true).timeout.connect(func():
			var u := InputEventJoypadButton.new()
			u.device = dev
			u.button_index = b.button_index
			u.pressed = false
			Input.parse_input_event(u))
	else:
		var p := spec.substr(5).split(";")
		var m := InputEventJoypadMotion.new()
		m.device = dev
		m.axis = int(p[0]) as JoyAxis
		m.axis_value = float(p[1])
		Input.parse_input_event(m)
	print("CAPTURE pad ", spec, " at ", snappedf(_t, 0.01))
