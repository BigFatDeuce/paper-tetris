class_name Director
extends Node2D
## Runs the decorative Shy Guy crowd of a scene: spawns it for the stage,
## gives every actor a little life (wander, hop, chat, nap, dance...),
## makes them react to game events and stages rare appearances. Listens to
## Events only and never talks back to gameplay.

const BOARD_X := 960.0
const CROWD_SIZES := [0, 3, 6, 10]
const CHAR_DIR := "res://assets/sprites/characters/"

var stage_id := ""
var zones: Array = []       # Array[Rect2] ground areas (feet y inside)
var platforms: Array = []   # Array[Rect2] windows the actors may stand on
var actors: Array = []      # the crowd
var mood := "calm"          # calm, nervous, sad, party
var in_menu := false
## The well: whoever walks (or flies) behind it fades out, so no Shy Guy
## shows through the stacked pieces. Empty outside a game.
var hide_rect := Rect2()

var _rare_t := 0.0
var _level := 2             # crowd size index, rolled per scene in Random mode
var _random := false
var _rare_busy := false
var _parade := false


func _ready() -> void:
	y_sort_enabled = true
	Events.game_event.connect(_on_event)
	Settings.changed.connect(func(k: String):
		if k == "crowd" and not _parade:
			_respawn(false))


func setup(id: String, ground_zones: Array, tops: Array = []) -> void:
	stage_id = id
	zones = ground_zones
	platforms = tops
	in_menu = zones.size() == 1
	_roll_level()
	_rare_t = randf_range(8.0, 16.0) if in_menu else randf_range(18.0, 30.0)
	_spawn_crowd(false)


func change_stage(id: String) -> void:
	stage_id = id
	# the old troupe hurries off stage, the new one walks in
	for a: Actor in actors:
		_exit(a)
	actors.clear()
	await get_tree().create_timer(1.1, false).timeout
	_spawn_crowd(true)


## Crowd setting 4 is Random: a new size and a mixed cast on every load.
func _roll_level() -> void:
	var v := clampi(int(Settings.get_value("crowd")), 0, 4)
	_random = v == 4
	_level = randi_range(1, 3) if _random else v


func _respawn(enter: bool) -> void:
	_roll_level()
	for a: Actor in actors:
		if is_instance_valid(a):
			a.pop_out()
	actors.clear()
	_spawn_crowd(enter)


# ------------------------------------------------------------------ crowd

func _crowd_keys(n: int) -> Array:
	var info := StageLibrary.get_stage(stage_id)
	var base: Array = info.get("crowd", ["shyguy_red"]).duplicate()
	if _random:
		# everyone's invited: the regulars of every stage
		for sid: String in StageLibrary.ids():
			for k: String in StageLibrary.get_stage(sid).get("crowd", []):
				if not k in base:
					base.append(k)
		base.shuffle()
	var specials: Array = info.get("specials", [])
	var keys: Array = []
	for i in n:
		keys.append(base[i % base.size()])
	keys.shuffle()
	# a lively crowd always has a special guest
	if n >= 6:
		for sp: String in specials:
			if sp in ["groove_guy", "spy_guy", "spear_guy", "pyro_guy", "traffic_guy"]:
				keys[0] = sp
				break
	return keys


func _spawn_crowd(enter: bool) -> void:
	if zones.is_empty():
		return
	var n: int = CROWD_SIZES[_level]
	if n == 0:
		return
	var keys := _crowd_keys(n)
	var sitter := -1
	if not in_menu and n >= 6 and not platforms.is_empty():
		sitter = n - 1
	for i in n:
		var a: Actor
		if i == sitter:
			a = _spawn_on_platform(keys[i])
		else:
			var zone: Rect2 = zones[i % zones.size()]
			var front := (i / zones.size()) % 2 == 0
			var s := 3 if front else 2
			var y := zone.end.y - randf_range(4, 26) if front else zone.position.y + randf_range(8, 26)
			var x := randf_range(zone.position.x + 30, zone.end.x - 30)
			a = Actor.make(keys[i], s)
			a.position = Vector2(x, y)
			a.bounds = Vector2(zone.position.x + 20, zone.end.x - 20)
			add_child(a)
			if enter:
				var from_left := x < BOARD_X
				var target := x
				a.position.x = -120.0 if from_left else 2040.0
				_enter(a, target, 0.15 * i)
			else:
				a.pop_in(0.1 + 0.07 * i)
		a.face(1 if a.position.x < BOARD_X else -1, true)
		a.home = a.position
		actors.append(a)
		_life(a)


func _spawn_on_platform(key: String) -> Actor:
	var r: Rect2 = platforms[randi() % platforms.size()]
	var left := randf() < 0.5
	var x := r.position.x + 36.0 if left else r.end.x - 36.0
	var a := Actor.make(key, 2)
	a.position = Vector2(x, r.position.y + 5.0)
	a.bounds = Vector2(x - 12.0, x + 12.0)
	add_child(a)
	a.pop_in(0.6)
	a.set_meta("platform", true)
	return a


func _enter(a: Actor, x: float, delay: float) -> void:
	a.set_meta("entering", true)
	var id := a.begin_sequence()
	await a.wait(delay)
	if not a.is_current(id):
		return
	await a.go_to_free(x, true)
	if is_instance_valid(a):
		a.remove_meta("entering")
	if a.is_current(id):
		a.set_pose("idle")
		a.face_x(BOARD_X)
		a.end_sequence(id)


func _exit(a: Actor) -> void:
	if not is_instance_valid(a):
		return
	var id := a.begin_sequence()
	var x := -160.0 if a.position.x < BOARD_X else 2080.0
	if a.has_meta("platform"):
		a.pop_out()
		return
	await a.go_to_free(x, true)
	if is_instance_valid(a):
		a.queue_free()


# ------------------------------------------------------------------- life

func _life(a: Actor) -> void:
	await a.wait(randf_range(0.6, 2.4))
	while is_instance_valid(a) and a.is_inside_tree() and actors.has(a):
		if a.busy:
			await a.wait(0.3)
			continue
		var id := a.begin_sequence()
		await _idle_behaviour(a, id)
		if not is_instance_valid(a):
			return
		a.end_sequence(id)
		await a.wait(randf_range(0.7, 3.0))


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


func _idle_behaviour(a: Actor, id: int) -> void:
	var on_platform := a.has_meta("platform")
	var w := {}
	match mood:
		"sad":
			w = {"mope": 5, "look": 1}
		"party":
			w = {"cheer": 4, "dance": 3, "hop": 3}
		"nervous":
			w = {"nervous": 4, "look_board": 3, "wander": 1, "hop": 1}
		_:
			if on_platform:
				w = {"sit": 6, "look": 2, "hop": 1, "emote": 1}
			else:
				w = {"wander": 6, "look": 3, "hop": 2, "emote": 1.5, "chat": 1.5, "nap": 0.6,
					"run": 1, "look_board": 2, "dance": 0.5}
				if a.key in ["groove_guy", "spear_guy", "traffic_guy"]:
					w["dance"] = 4
				if not in_menu and zones.size() > 1:
					w["cross"] = 0.4
	match _pick(w):
		"wander":
			var x := clampf(a.position.x + randf_range(-260, 260), a.bounds.x, a.bounds.y)
			await a.go_to(x)
			if a.is_current(id):
				a.set_pose("idle")
				await a.wait(randf_range(0.6, 2.0))
		"run":
			var x2 := a.bounds.x if a.position.x > (a.bounds.x + a.bounds.y) * 0.5 else a.bounds.y
			await a.go_to(x2, true)
			if a.is_current(id):
				a.set_pose("idle")
				await a.wait(0.8)
		"look":
			a.face(-a.facing)
			a.set_pose("idle")
			await a.wait(randf_range(1.0, 2.5))
		"look_board":
			a.face_x(BOARD_X)
			a.set_pose("look_up")
			await a.wait(randf_range(1.0, 2.0))
			if a.is_current(id):
				a.set_pose("idle")
		"hop":
			for i in randi_range(1, 2):
				await a.hop()
				if not a.is_current(id):
					return
		"emote":
			a.emote(["♪", "?", "!", "♡"].pick_random())
			a.set_pose("front" if randf() < 0.4 else "idle")
			await a.wait(1.4)
		"chat":
			var other := _nearest(a)
			if other and not other.busy and absf(other.position.x - a.position.x) < 260.0:
				a.face_x(other.position.x)
				other.face_x(a.position.x)
				a.emote(["♪", "?", "♡", "!"].pick_random(), 1.2)
				await a.wait(1.0)
				if is_instance_valid(other) and not other.busy:
					other.emote(["♪", "!", "♡"].pick_random(), 1.0)
				await a.wait(1.2)
		"nap":
			a.set_pose("sleep")
			a.emote("z", 2.4)
			await a.wait(randf_range(3.0, 5.0))
			if a.is_current(id):
				await a.hop()
		"dance":
			a.set_pose("dance")
			await a.wait(randf_range(2.0, 4.0))
			if a.is_current(id):
				a.set_pose("idle")
		"sit":
			a.set_pose("sit")
			await a.wait(randf_range(2.5, 5.0))
			if a.is_current(id):
				a.face(-a.facing)
		"cross":
			var other_zone: Rect2 = zones[0] if a.position.x > BOARD_X else zones[1]
			a.bounds = Vector2(-100, 2020)
			var tx := randf_range(other_zone.position.x + 30, other_zone.end.x - 30)
			await a.go_to(tx)
			a.bounds = Vector2(other_zone.position.x + 20, other_zone.end.x - 20)
			if a.is_current(id):
				a.face_x(BOARD_X)
		"nervous":
			a.face_x(BOARD_X)
			a.set_pose("panic" if randf() < 0.4 else "look_up")
			if randf() < 0.3:
				a.emote("!", 0.9)
			await a.wait(randf_range(0.8, 1.6))
		"mope":
			a.set_pose("lie" if randf() < 0.6 else "dizzy")
			await a.wait(randf_range(2.0, 4.0))
		"cheer":
			a.face_x(BOARD_X)
			a.set_pose("cheer")
			await a.wait(randf_range(0.8, 1.6))


func _nearest(a: Actor) -> Actor:
	var best: Actor = null
	var bd := INF
	for o: Actor in actors:
		if o == a or not is_instance_valid(o):
			continue
		var d := absf(o.position.x - a.position.x) + absf(o.position.y - a.position.y) * 2.0
		if d < bd:
			bd = d
			best = o
	return best


# -------------------------------------------------------------- reactions

## Actors that may react right now (not still walking onto the stage).
func _valid_actors() -> Array:
	return actors.filter(func(x): return is_instance_valid(x) and x.is_inside_tree() 		and not x.has_meta("entering") and x.position.x > -20.0 and x.position.x < 1940.0)


func _react(a: Actor, kind: String, delay := 0.0) -> void:
	var id := a.begin_sequence()
	if delay > 0.0:
		await a.wait(delay)
		if not a.is_current(id):
			return
	match kind:
		"hop":
			a.face_x(BOARD_X)
			await a.hop()
		"cheer":
			a.face_x(BOARD_X)
			a.set_pose("cheer")
			await a.wait(0.35)
			if a.is_current(id):
				await a.jump(60.0 + a.px_scale * 8.0, 0.5)
			if a.is_current(id):
				a.set_pose("cheer")
				await a.wait(0.9)
		"party":
			a.face_x(BOARD_X)
			for i in 2:
				if not a.is_current(id):
					return
				await a.jump(70.0 + a.px_scale * 10.0, 0.55)
			if a.is_current(id):
				a.set_pose("dance" if a.key in ["groove_guy", "spear_guy"] else "cheer")
				await a.wait(1.4)
		"spin":
			a.set_pose("spin")
			await a.wait(0.8)
			if a.is_current(id):
				await a.hop()
		"dance":
			a.set_pose("dance")
			await a.wait(2.6)
		"flinch":
			a.set_pose("crouch")
			await a.wait(0.35)
		"look":
			a.face_x(BOARD_X)
			a.set_pose("look_up")
			await a.wait(1.0)
		"panic":
			a.face_x(BOARD_X)
			a.emote("!", 1.0)
			a.set_pose("panic")
			await a.wait(1.2)
			if a.is_current(id):
				a.set_pose("look_up")
				await a.wait(0.6)
		"relief":
			a.emote("♪", 1.0)
			await a.hop()
		"fall":
			a.set_pose("tumble")
			await a.jump(30.0, 0.4)
			if a.is_current(id):
				a.set_pose("lie" if randf() < 0.65 else "dizzy")
				await a.wait(2.5)
		"surprise":
			a.emote("!", 0.9)
			await a.hop()
		"question":
			a.emote("?", 1.0)
			await a.wait(1.0)
	if is_instance_valid(a):
		a.end_sequence(id)


func _react_some(kind: String, fraction: float, max_delay := 0.25) -> void:
	var list := _valid_actors()
	list.shuffle()
	var n := clampi(int(ceil(list.size() * fraction)), 0, list.size())
	for i in n:
		_react(list[i], kind, randf_range(0.0, max_delay))


func _on_event(kind: StringName, data: Dictionary) -> void:
	if _parade:
		return
	match kind:
		&"lines":
			var n := int(data.get("lines", 0))
			if n >= 4 or n == 0:
				return
			if n == 1:
				_react_some("hop", 0.25)
			elif n == 2:
				_react_some("cheer", 0.35)
			else:
				_react_some("cheer", 0.6)
		&"tetris":
			for a: Actor in _valid_actors():
				_react(a, "dance" if a.key == "groove_guy" else "cheer", randf_range(0.0, 0.2))
			_hearts(0.5)
		&"tspin":
			_react_some("spin", 0.5)
		&"combo":
			if int(data.get("combo", 0)) >= 3:
				_react_some("surprise", 0.25)
		&"perfect":
			_react_some("party", 1.0)
			_hearts(1.0)
		&"level_up":
			_react_some("look", 0.5)
			_rare_t = minf(_rare_t, randf_range(1.5, 4.0))
		&"hard_drop":
			if int(data.get("rows", 0)) >= 8:
				for a: Actor in _valid_actors():
					if a.px_scale >= 3 and absf(a.position.x - BOARD_X) < 700 and randf() < 0.5:
						_react(a, "flinch")
		&"lock":
			if randf() < 0.06:
				_react_some("look", 0.15)
		&"danger":
			if bool(data.get("on", false)):
				mood = "nervous"
				_react_some("panic", 0.8, 0.5)
			else:
				if mood == "nervous":
					mood = "calm"
					_react_some("relief", 0.5, 0.4)
		&"game_start":
			mood = "calm"
			_react_some("surprise", 0.3, 0.4)
		&"game_over":
			mood = "sad"
			for a: Actor in _valid_actors():
				_react(a, "fall", randf_range(0.0, 0.5))
		&"game_clear", &"new_record":
			mood = "party"
			_react_some("party", 1.0, 0.4)
			_hearts(0.8)
		&"hold":
			if randf() < 0.15:
				_react_some("question", 0.15)
		&"menu_select":
			_react_some("hop", 0.2, 0.15)
		&"menu_back":
			if randf() < 0.4:
				_react_some("look", 0.15)


# ----------------------------------------------------------------- rares

func _process(delta: float) -> void:
	if hide_rect.has_area():
		_fade_behind_well()
	if _parade or zones.is_empty():
		return
	_rare_t -= delta
	if _rare_t <= 0.0 and not _rare_busy:
		_rare_t = randf_range(10.0, 22.0) if in_menu else randf_range(22.0, 45.0)
		if _level > 0:
			_rare_event()


func _fade_behind_well() -> void:
	const SOFT := 70.0   # px over which an actor fades as it slips behind
	for c in get_children():
		if not c is Actor:
			continue
		var a := c as Actor
		var top := a.position.y - a.height_px()
		if a.position.y < hide_rect.position.y or top > hide_rect.end.y:
			a.modulate.a = 1.0
			continue
		var d := maxf(hide_rect.position.x - a.position.x, a.position.x - hide_rect.end.x)
		a.modulate.a = clampf(d / SOFT, 0.0, 1.0)


func _rare_event() -> void:
	var info := StageLibrary.get_stage(stage_id)
	var pool: Array = info.get("rare", []) + info.get("specials", [])
	if pool.is_empty():
		return
	var who: String = pool.pick_random()
	_rare_busy = true
	match who:
		"sky_guy": await _flyby()
		"general_guy": await _general_parade()
		"stilt_guy": await _stilt_walk()
		"spy_guy": await _peek("spy_guy", "sit")
		"traffic_guy": await _visit("traffic_guy", "signal")
		"groove_guy": await _visit("groove_guy", "dance")
		_: await _walk_across(who)
	_rare_busy = false


func _ground_y(front := true) -> float:
	var z: Rect2 = zones[0]
	return z.end.y - 10.0 if front else z.position.y + 14.0


func _flyby() -> void:
	var a := Actor.make("sky_guy", 3)
	a.airborne = true
	var ltr := randf() < 0.5
	var y := randf_range(150.0, 260.0)
	a.position = Vector2(-160.0 if ltr else 2080.0, y)
	add_child(a)
	a.face(1 if ltr else -1, true)
	a.set_pose("hold")
	var col: String = ["red", "orange", "blue"].pick_random()
	var head := a.height_px()
	a.add_part(load(CHAR_DIR + "sky_guy_string.png"), Vector2(-2, -head - 22), true)
	a.add_part(load(CHAR_DIR + "sky_guy_balloon_%s.png" % col), Vector2(-2, -head - 100), true)
	var dur := randf_range(13.0, 17.0)
	var t := 0.0
	var start := a.position.x
	var end := 2080.0 if ltr else -160.0
	while t < dur and is_instance_valid(a) and is_inside_tree():
		t += get_process_delta_time()
		a.position.x = lerpf(start, end, t / dur)
		a.position.y = y + sin(t * 1.7) * 18.0
		a.rotation = sin(t * 1.3) * 0.05
		if randf() < 0.002:
			a.emote("♪", 1.0)
		await get_tree().process_frame
	if is_instance_valid(a):
		a.queue_free()


func _walk_across(key: String) -> void:
	var a := Actor.make(key, 3)
	var ltr := randf() < 0.5
	a.position = Vector2(-140.0 if ltr else 2060.0, _ground_y(randf() < 0.5))
	add_child(a)
	var id := a.begin_sequence()
	if key in ["spear_guy", "pyro_guy"]:
		# hop hop hop across
		var x := a.position.x
		var step := 140.0 if ltr else -140.0
		while is_instance_valid(a) and a.is_inside_tree() and ((ltr and x < 2060.0) or (not ltr and x > -140.0)):
			x += step
			a.face(1 if ltr else -1)
			var tw := a.create_tween()
			tw.tween_property(a, "position:x", x, 0.42)
			await a.jump(50.0, 0.42)
	else:
		# a stranger passes by: the crowd notices
		if key == "anti_guy":
			get_tree().create_timer(2.0, false).timeout.connect(func(): _react_some("surprise", 0.4, 1.0))
		await a.go_to_free(2060.0 if ltr else -140.0)
	if is_instance_valid(a):
		a.end_sequence(id)
		a.queue_free()


func _general_parade() -> void:
	var ltr := randf() < 0.5
	var y := _ground_y(true)
	var keys := ["general_guy", "shyguy_red", "shyguy_blue", "shyguy_green", "shyguy_yellow"]
	var troop: Array = []
	for i in keys.size():
		var a := Actor.make(keys[i], 3)
		a.position = Vector2((-150.0 - i * 120.0) if ltr else (2070.0 + i * 120.0), y - (i % 2) * 6.0)
		add_child(a)
		a.speed_walk = 80.0
		troop.append(a)
	for a: Actor in troop:
		a.go_to_free(2300.0 + 600.0 if ltr else -900.0)
	# the crowd salutes as the general passes
	get_tree().create_timer(4.0, false).timeout.connect(func(): _react_some("cheer", 0.5, 1.5))
	await get_tree().create_timer(32.0, false).timeout
	for a: Actor in troop:
		if is_instance_valid(a):
			a.queue_free()


func _stilt_walk() -> void:
	var a := Actor.make("stilt_guy", 2)
	var ltr := randf() < 0.5
	a.position = Vector2(-120.0 if ltr else 2040.0, _ground_y(false))
	add_child(a)
	a.set_stilts(load(CHAR_DIR + "stilt_guy_stilt.png"))
	a.speed_walk = 55.0
	a.face(1 if ltr else -1, true)
	a.go_to_free(2040.0 if ltr else -120.0)
	a.set_pose("walk")
	await get_tree().create_timer(40.0, false).timeout
	if is_instance_valid(a):
		a.queue_free()


func _peek(key: String, anim: String) -> void:
	var a := Actor.make(key, 3)
	var left := randf() < 0.5
	var y := _ground_y(true)
	a.position = Vector2(-80.0 if left else 2000.0, y)
	add_child(a)
	var id := a.begin_sequence()
	await a.go_to_free(70.0 if left else 1850.0)
	if not is_instance_valid(a):
		return
	a.set_pose(anim)
	a.emote("?", 1.2)
	await a.wait(4.0)
	if not is_instance_valid(a):
		return
	await a.go_to_free(-120.0 if left else 2040.0, true)
	if is_instance_valid(a):
		a.end_sequence(id)
		a.queue_free()


func _visit(key: String, anim: String) -> void:
	var a := Actor.make(key, 3)
	var left := randf() < 0.5
	var zone: Rect2 = zones[0] if left or zones.size() == 1 else zones[1]
	a.position = Vector2(-100.0 if left else 2020.0, _ground_y(true))
	add_child(a)
	var id := a.begin_sequence()
	await a.go_to_free(randf_range(zone.position.x + 60, zone.end.x - 60))
	if not is_instance_valid(a):
		return
	a.face_x(BOARD_X)
	a.set_pose(anim)
	await a.wait(5.0)
	if not is_instance_valid(a):
		return
	await a.go_to_free(-120.0 if left else 2040.0)
	if is_instance_valid(a):
		a.end_sequence(id)
		a.queue_free()


# ---------------------------------------------------------------- credits

## Endless parade of the whole cast (credits screen).
func parade() -> void:
	_parade = true
	for a: Actor in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()
	var cast := ["general_guy", "shyguy_red", "shyguy_blue", "shyguy_green", "shyguy_pink", "shyguy_yellow",
		"groove_guy", "spear_guy", "pyro_guy", "traffic_guy", "spy_guy", "anti_guy"]
	var spacing := 175.0
	var total := spacing * cast.size()
	for i in cast.size():
		var a := Actor.make(cast[i], 3)
		a.position = Vector2(-150.0 - i * spacing, 1000.0)
		add_child(a)
		a.speed_walk = 75.0
		a.face(1, true)
		_parade_loop(a, total)
	var sky := Actor.make("sky_guy", 3)
	sky.airborne = true
	sky.position = Vector2(-300, 200)
	add_child(sky)
	sky.face(1, true)
	sky.set_pose("hold")
	sky.add_part(load(CHAR_DIR + "sky_guy_string.png"), Vector2(-2, -sky.height_px() - 22), true)
	sky.add_part(load(CHAR_DIR + "sky_guy_balloon_red.png"), Vector2(-2, -sky.height_px() - 100), true)
	_sky_loop(sky)


func _parade_loop(a: Actor, total: float) -> void:
	while is_instance_valid(a) and a.is_inside_tree():
		await a.go_to_free(2100.0)
		if not is_instance_valid(a):
			return
		a.position.x -= total + 150.0
		if a.position.x > -200.0:
			a.position.x = -200.0
		if randf() < 0.3:
			a.emote(["♪", "♡", "!"].pick_random(), 1.0)


func _sky_loop(a: Actor) -> void:
	var t := 0.0
	while is_instance_valid(a) and is_inside_tree():
		t += get_process_delta_time()
		a.position.x += 60.0 * get_process_delta_time()
		a.position.y = 200.0 + sin(t * 1.5) * 20.0
		if a.position.x > 2100.0:
			a.position.x = -300.0
		await get_tree().process_frame


## Some of the crowd send hearts (share = fraction of the visible actors).
func _hearts(share: float) -> void:
	for a: Actor in _valid_actors():
		if randf() < share:
			a.hearts(randi_range(2, 4))
