class_name Callouts
extends Node2D
## Juice layer above the well: clear words (NICE / GOOD / SUPER / LUCKY),
## captions, score pop-ups, confetti, countdown and banners. Purely visual.

const WORDS := {
	2: preload("res://assets/sprites/ui/word_nice.png"),
	3: preload("res://assets/sprites/ui/word_good.png"),
	4: preload("res://assets/sprites/ui/word_super.png"),
}
const WORD_LUCKY := preload("res://assets/sprites/ui/word_lucky.png")
const WORD_MISS := preload("res://assets/sprites/ui/word_miss.png")
const BURST_100 := preload("res://assets/sprites/ui/burst_100.png")
const CONFETTI := preload("res://assets/ui/confetti.png")
const SPARKLE := preload("res://assets/sprites/ui/item_star.png")   # the Paper Mario star
const STAR_SPIN := preload("res://assets/sprites/ui/star_spin.png")
const NUMS := [
	null,
	preload("res://assets/sprites/ui/num_orange_1.png"),
	preload("res://assets/sprites/ui/num_orange_2.png"),
	preload("res://assets/sprites/ui/num_orange_3.png"),
	preload("res://assets/sprites/ui/num_orange_4.png"),
	preload("res://assets/sprites/ui/num_orange_5.png"),
	preload("res://assets/sprites/ui/num_orange_6.png"),
	preload("res://assets/sprites/ui/num_orange_7.png"),
]
const COIN_SPIN := preload("res://assets/sprites/ui/coin_spin.png")
const CLOUD := preload("res://assets/sprites/ui/cloud.png")
const PAPER_COLORS := [
	Color("ec4a3c"), Color("ffd23f"), Color("3ec6ee"), Color("5cc83c"),
	Color("b05ce0"), Color("f68a2e"), Color("ffffff"), Color("ff8fc8"),
]

var board: BoardView
var _caption_stack: Array = []
var _word: Node2D


func setup(b: BoardView) -> void:
	board = b


func _well_center() -> Vector2:
	return board.position + board.well_size() * 0.5


func _particles_on() -> bool:
	return bool(Settings.get_value("particles"))


# ------------------------------------------------------------ line clears

func clear_callout(result: Dictionary, rows: Array) -> void:
	var n: int = result["lines"]
	var tspin: int = result["tspin"]
	var center := _well_center()
	var row_y := center.y
	if not rows.is_empty():
		var sum := 0.0
		for r: int in rows:
			sum += board.cell_pos(Vector2i(0, r)).y + BoardView.CELL * 0.5
		row_y = board.position.y + sum / rows.size()
	# confetti along each cleared row
	if _particles_on():
		for r: int in rows:
			var y := board.position.y + board.cell_pos(Vector2i(0, r)).y + BoardView.CELL * 0.5
			confetti(Vector2(center.x, y), 10 + n * 4, Vector2(board.well_size().x * 0.5, 8))
	# big word
	var tex: Texture2D = null
	if result.get("perfect", false):
		tex = BURST_100
	elif tspin != TetrisEngine.TSpin.NONE and n > 0:
		tex = WORD_LUCKY
	elif WORDS.has(n):
		tex = WORDS[n]
	if tex:
		_show_word(tex, Vector2(center.x, clampf(row_y - 150.0, board.position.y + 140.0, board.position.y + 640.0)), n >= 4 or result.get("perfect", false))
	# caption lines
	var lines: Array = []
	var name := ""
	match tspin:
		TetrisEngine.TSpin.FULL: name = "T-SPIN "
		TetrisEngine.TSpin.MINI: name = "T-SPIN MINI "
	name += ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS"][mini(n, 4)] if n > 0 else ""
	if name.strip_edges() != "":
		lines.append([name.strip_edges(), UIKit.CREAM])
	if result.get("b2b", false):
		lines.append(["BACK-TO-BACK", UIKit.GOLD])
	if int(result.get("combo", -1)) > 0:
		lines.append(["%d COMBO" % int(result["combo"]), Color("8fe0ff")])
		if int(result["combo"]) >= 2:
			combo_number(int(result["combo"]))
	if result.get("perfect", false):
		lines.append(["PERFECT CLEAR!", Color("ffd23f")])
	if not lines.is_empty():
		caption(lines)
	if int(result.get("points", 0)) > 0:
		score_popup(int(result["points"]), Vector2(center.x, row_y))


func _show_word(tex: Texture2D, pos: Vector2, big: bool) -> void:
	if is_instance_valid(_word):
		_word.queue_free()
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 20
	add_child(holder)
	_word = holder
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(spr)
	var final := 5.0 if big else 4.0
	holder.scale = Vector2(0.2, 0.2)
	holder.rotation = deg_to_rad(-12)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector2(final, final), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55 if not big else 0.8)
	tw.chain().set_parallel(true)
	tw.tween_property(holder, "position:y", pos.y - 60.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(holder.queue_free)
	if big and _particles_on():
		sparkles(pos, 10, 140.0)


func caption(lines: Array) -> void:
	for c in _caption_stack:
		if is_instance_valid(c):
			c.queue_free()
	_caption_stack.clear()
	var center := _well_center()
	var y := board.position.y + board.well_size().y * 0.5 + 40.0
	for i in lines.size():
		var l := UIKit.label(str(lines[i][0]), 3, lines[i][1], HORIZONTAL_ALIGNMENT_CENTER, true)
		l.size = Vector2(600, 60)
		l.position = Vector2(center.x - 300.0, y + i * 58.0)
		l.pivot_offset = l.size * 0.5
		l.z_index = 19
		add_child(l)
		_caption_stack.append(l)
		l.scale = Vector2(0.6, 0.6)
		l.modulate.a = 0.0
		var tw := l.create_tween()
		tw.tween_interval(0.05 * i)
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 1.0, 0.12)
		tw.chain().tween_interval(1.0)
		tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(l.queue_free)


func score_popup(points: int, pos: Vector2) -> void:
	var l := UIKit.label("+" + UIKit.format_int(points), 2, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.size = Vector2(300, 40)
	l.position = pos - Vector2(150, 20)
	l.z_index = 18
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 90.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------- particles

func confetti(pos: Vector2, amount: int, extents := Vector2(10, 10), up := 420.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = CONFETTI
	p.amount = maxi(amount, 1)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = up * 0.45
	p.initial_velocity_max = up
	p.gravity = Vector2(0, 900)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 2.6
	p.color_initial_ramp = _paper_ramp()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	p.color_ramp = fade
	p.position = pos
	p.z_index = 15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


static var _ramp: Gradient


static func _paper_ramp() -> Gradient:
	if _ramp == null:
		_ramp = Gradient.new()
		_ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for i in PAPER_COLORS.size():
			offs.append(float(i) / PAPER_COLORS.size())
			cols.append(PAPER_COLORS[i])
		_ramp.offsets = offs
		_ramp.colors = cols
	return _ramp


func sparkles(pos: Vector2, amount: int, radius: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = SPARKLE
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.8
	p.lifetime = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = pos
	p.z_index = 21
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


## Puff of paper dust under a hard-dropped piece.
func dust(cells: Array) -> void:
	if not _particles_on() or cells.is_empty():
		return
	var bottom := -1
	var xs: Array = []
	for c: Vector2i in cells:
		bottom = maxi(bottom, c.y)
	for c: Vector2i in cells:
		if c.y == bottom:
			xs.append(c.x)
	var y_px := board.position.y + board.cell_pos(Vector2i(0, bottom)).y + BoardView.CELL
	dust_clouds(Vector2(board.position.x + board.cell_pos(Vector2i(xs.min(), bottom)).x, y_px),
		Vector2(board.position.x + board.cell_pos(Vector2i(xs.max(), bottom)).x + BoardView.CELL, y_px), xs.size() >= 3)
	for x: int in xs:
		var pos := board.position + board.cell_pos(Vector2i(x, bottom)) + Vector2(BoardView.CELL * 0.5, BoardView.CELL)
		var p := CPUParticles2D.new()
		p.texture = CONFETTI
		p.amount = 5
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.45
		p.direction = Vector2(0, -1)
		p.spread = 80.0
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 150.0
		p.gravity = Vector2(0, 400)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 1.6
		p.color = Color(1, 0.97, 0.88, 0.9)
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		p.position = pos
		p.z_index = 14
		add_child(p)
		p.emitting = true
		get_tree().create_timer(0.8).timeout.connect(p.queue_free)


# --------------------------------------------------------------- banners

## 3, 2, 1, GO! Await it.
func countdown() -> void:
	var center := _well_center() + Vector2(0, -40)
	for n in [3, 2, 1]:
		var spr := Sprite2D.new()
		spr.texture = NUMS[n]
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = center
		spr.z_index = 30
		add_child(spr)
		spr.scale = Vector2(1, 1)
		Audio.sfx("count")
		var tw := create_tween()
		tw.tween_property(spr, "scale", Vector2(7, 7), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.42)
		tw.parallel().tween_property(spr, "rotation", deg_to_rad(4 if n % 2 == 0 else -4), 0.42)
		tw.tween_property(spr, "scale", Vector2(0.5, 0.5), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(spr.queue_free)
		await get_tree().create_timer(0.76, false).timeout
	Audio.sfx("go")
	banner("GO!", UIKit.GOLD, 0.45)
	if _particles_on():
		confetti(center + Vector2(0, 20), 26, Vector2(80, 10), 520.0)
	await get_tree().create_timer(0.15, false).timeout


## Large centred text (x4 font, doubled). Returns the label.
func banner(text: String, color: Color, hold := 1.2, y_offset := -40.0, scale_to := 2.0) -> Label:
	var center := _well_center() + Vector2(0, y_offset)
	var l := UIKit.label(text, 4, color, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.size = Vector2(800, 90)
	l.position = center - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.z_index = 30
	add_child(l)
	l.scale = Vector2(0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(scale_to, scale_to), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold >= 0.0:
		tw.tween_interval(hold)
		tw.tween_property(l, "modulate:a", 0.0, 0.25)
		tw.tween_callback(l.queue_free)
	return l


func level_up(level: int) -> void:
	banner(tr("LEVEL %d") % level, UIKit.GOLD, 0.9, 260.0, 1.0)
	if _particles_on():
		sparkles(_well_center() + Vector2(0, 260), 12, 160.0)
		star_ring(_well_center() + Vector2(0, 260), 10, 260.0)


func miss() -> void:
	_show_word(WORD_MISS, _well_center() + Vector2(0, -150), true)


# ------------------------------------------------- Paper Mario extras

## Spinning coins hop out of the cleared rows and fly into the score.
## `on_arrive` is called as each coin lands (e.g. to bump the counter).
func coin_shower(from: Vector2, to: Vector2, count: int, on_arrive: Callable = Callable()) -> void:
	if to == Vector2.ZERO:
		return
	for i in count:
		var coin := SheetIcon.make(COIN_SPIN, 9, 2, 18.0)
		coin.size = coin.custom_minimum_size
		coin.pivot_offset = coin.size * 0.5
		var start := from + Vector2(randf_range(-150, 150), randf_range(-10, 10)) - coin.size * 0.5
		coin.position = start
		coin.z_index = 22
		add_child(coin)
		var peak := start + Vector2(randf_range(-60, 60), randf_range(-170, -110))
		var end := to - coin.size * 0.5
		var tw := coin.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(coin, "position", peak, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "position", end, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin, "scale", Vector2(0.6, 0.6), 0.42)
		tw.tween_callback(func():
			Audio.sfx("pm_ching", randf_range(0.95, 1.15), -10.0)
			if on_arrive.is_valid():
				on_arrive.call()
			coin.queue_free())


## Paper Mario landing dust: two little clouds puff out sideways.
func dust_clouds(left: Vector2, right: Vector2, big: bool) -> void:
	if not _particles_on():
		return
	for side in [-1, 1]:
		var s := Sprite2D.new()
		s.texture = CLOUD
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = (left if side < 0 else right) + Vector2(side * 6, -10)
		s.flip_h = side > 0
		s.z_index = 15
		var sc := 1.5 if big else 1.1
		s.scale = Vector2(sc, sc) * 0.4
		add_child(s)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", s.position + Vector2(side * (70 if big else 45), -18), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(sc, sc), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.22).set_delay(0.18)
		tw.chain().tween_callback(s.queue_free)


## The orange Action Command number (combo 2..7, then stays 7) pops beside the well.
func combo_number(combo: int) -> void:
	var n := clampi(combo, 1, 7)
	var spr := Sprite2D.new()
	spr.texture = NUMS[n]
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = board.position + Vector2(board.well_size().x - 40, 120)
	spr.z_index = 24
	spr.rotation = deg_to_rad(-10)
	add_child(spr)
	spr.scale = Vector2(1, 1)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", Vector2(5, 5), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "rotation", deg_to_rad(8), 0.18)
	tw.tween_property(spr, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(spr, "position:y", spr.position.y - 40, 0.25)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(spr.queue_free)


## A ring of spinning Paper Mario stars bursting out of a point.
func star_ring(pos: Vector2, count := 8, radius := 220.0) -> void:
	if not _particles_on():
		return
	for i in count:
		var st := SheetIcon.make(STAR_SPIN, 8, 4, 16.0)
		st.size = st.custom_minimum_size
		st.pivot_offset = st.size * 0.5
		st.position = pos - st.size * 0.5
		st.z_index = 23
		add_child(st)
		var a := TAU * i / count + randf_range(-0.15, 0.15)
		var tw := st.create_tween().set_parallel(true)
		tw.tween_property(st, "position", st.position + Vector2(cos(a), sin(a) * 0.6) * radius, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(st, "modulate:a", 0.0, 0.25).set_delay(0.45)
		tw.chain().tween_callback(st.queue_free)
