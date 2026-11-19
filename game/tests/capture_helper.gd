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
	if args.get("demo", "0") == "1" and scene and scene.get("engine") != null and not _demo_done:
		var e: TetrisEngine = scene.engine
		if e.state == TetrisEngine.State.FALLING:
			_demo_done = true
			_setup_demo(e)
	if args.get("bot", "0") == "1" and scene and scene.get("engine") != null:
		_bot(scene.engine, delta)
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
