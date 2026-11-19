class_name StageView
extends Node2D
## Paper diorama behind the board. Loads the layered art of a stage from
## assets/stages/<id>/ (layers.json), sways the cut-outs gently, emits the
## stage's ambient particles and plays the pop-up book transition when the
## stage changes. Layers flagged "front" (and the ambience) live in `front`,
## a separate node the owning scene adds above its actors.

signal stage_changed(id: String)

const SCREEN := Vector2(1920, 1080)

var stage_id := ""
var front: Node2D            # add it to the scene after the actors
var ground_y := 935.0

var _root: Node2D
var _front_root: Node2D
var _time := 0.0
var _layers: Array = []      # [{node, sway, depth}]
var _ambient: Node2D


func _init() -> void:
	front = Node2D.new()
	front.name = "StageFront"


func _ready() -> void:
	_root = Node2D.new()
	add_child(_root)
	_front_root = Node2D.new()
	front.add_child(_front_root)
	_ensure_front.call_deferred()
	Settings.changed.connect(func(k: String):
		if k == "particles":
			_make_ambient())
	tree_exiting.connect(func():
		if is_instance_valid(front) and front.get_parent() == null:
			front.queue_free())


## The owner normally adds `front` above its actors; if it did not, keep
## it right after the stage.
func _ensure_front() -> void:
	if is_instance_valid(front) and front.get_parent() == null and get_parent():
		get_parent().add_child(front)
		get_parent().move_child(front, get_index() + 1)


func setup(id: String) -> void:
	_build(id)


func change_to(id: String) -> void:
	if id == stage_id:
		return
	# fold the current diorama down like a pop-up book page, then unfold the next
	var tw := create_tween().set_parallel(true)
	for i in _layers.size():
		var n: Node2D = _layers[i]["node"]
		tw.tween_property(n, "scale:y", 0.0, 0.35).set_delay(0.04 * (_layers.size() - i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _ambient:
		tw.tween_property(_ambient, "modulate:a", 0.0, 0.3)
	Audio.sfx("page_turn")
	await tw.finished
	for c in _root.get_children():
		c.queue_free()
	for c in _front_root.get_children():
		c.queue_free()
	_build(id)
	for i in _layers.size():
		var n: Node2D = _layers[i]["node"]
		n.scale.y = 0.0
		var t2 := create_tween()
		t2.tween_property(n, "scale:y", 1.0, 0.5).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("stage_pop")


func _build(id: String) -> void:
	stage_id = id
	_layers.clear()
	var info := StageLibrary.get_stage(id)
	var folder := StageLibrary.folder(id)
	var meta_path := folder + "layers.json"
	var meta: Variant = null
	if FileAccess.file_exists(meta_path):
		meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if typeof(meta) == TYPE_DICTIONARY:
		ground_y = float(meta.get("ground", 935.0))
		for l: Dictionary in meta.get("layers", []):
			var tex: Texture2D = load(folder + str(l["file"]))
			if tex == null:
				continue
			var holder := Node2D.new()
			# pivot at the layer's base so it unfolds from the ground (front
			# layers hanging from the ceiling unfold from the top)
			var base_y := float(l.get("base", SCREEN.y))
			var top_y := float(l.get("y", 0))
			var hanging: bool = bool(l.get("front", false)) and top_y <= 0.0 and base_y < SCREEN.y * 0.5
			var pivot := top_y if hanging else base_y
			holder.position = Vector2(0, pivot)
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.position = Vector2(float(l.get("x", 0)), top_y - pivot)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			holder.add_child(spr)
			if bool(l.get("front", false)):
				_front_root.add_child(holder)
			else:
				_root.add_child(holder)
			_layers.append({"node": holder, "sway": float(l.get("sway", 0.0)), "depth": float(l.get("depth", 0.0))})
	if _layers.is_empty():
		_fallback(info)
	_make_ambient()
	stage_changed.emit(id)


func _fallback(info: Dictionary) -> void:
	var holder := Node2D.new()
	holder.position = Vector2(0, SCREEN.y)
	var bg := ColorRect.new()
	bg.size = SCREEN
	bg.position = Vector2(0, -SCREEN.y)
	bg.color = Color(0.55, 0.78, 0.95) * Color(info.get("tint", Color.WHITE))
	holder.add_child(bg)
	var ground := ColorRect.new()
	ground.size = Vector2(SCREEN.x, 145)
	ground.position = Vector2(0, -145)
	ground.color = Color(0.45, 0.72, 0.35)
	holder.add_child(ground)
	_root.add_child(holder)
	_layers.append({"node": holder, "sway": 0.0, "depth": 0.0})


func _process(delta: float) -> void:
	_time += delta
	# gentle paper sway for the cut-outs that ask for it
	for l in _layers:
		var s: float = l["sway"]
		if s != 0.0:
			var n: Node2D = l["node"]
			n.skew = sin(_time * 0.9 + float(l["depth"]) * 2.3) * s * 0.008


# ------------------------------------------------------------------ ambience

func _make_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
	if not bool(Settings.get_value("particles")):
		return
	var kind: String = StageLibrary.get_stage(stage_id).get("ambient", "")
	_ambient = Node2D.new()
	_ambient.name = "Ambient"
	front.add_child(_ambient)
	var p := CPUParticles2D.new()
	p.position = Vector2(960, -30)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000, 10)
	p.preprocess = 8.0
	p.texture = load("res://assets/ui/confetti.png")
	match kind:
		"confetti":
			p.amount = 40
			p.lifetime = 10.0
			p.direction = Vector2(0, 1)
			p.spread = 20.0
			p.gravity = Vector2(0, 18)
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 80.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			p.angle_max = 360.0
			p.scale_amount_min = 1.4
			p.scale_amount_max = 2.2
			p.color_initial_ramp = _ramp(["ec4a3c", "ffd23f", "3ec6ee", "5cc83c", "b05ce0", "f68a2e"])
		"leaves":
			p.texture = load("res://assets/sprites/ui/leaf.png")
			p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p.amount = 7
			p.lifetime = 14.0
			p.direction = Vector2(0.4, 1)
			p.spread = 25.0
			p.gravity = Vector2(10, 12)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 60.0
			p.angular_velocity_min = -60.0
			p.angular_velocity_max = 60.0
			p.angle_max = 360.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.0
		"petals":
			p.amount = 30
			p.lifetime = 13.0
			p.direction = Vector2(0.5, 1)
			p.spread = 30.0
			p.gravity = Vector2(6, 14)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 60.0
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
			p.angle_max = 360.0
			p.scale_amount_min = 1.2
			p.scale_amount_max = 1.8
			p.color_initial_ramp = _ramp(["ff8fc8", "ffc0dc", "ffffff", "ffd23f"])
		"sand":
			p.position = Vector2(-40, 620)
			p.emission_rect_extents = Vector2(10, 420)
			p.amount = 60
			p.lifetime = 6.0
			p.direction = Vector2(1, -0.05)
			p.spread = 8.0
			p.gravity = Vector2(0, 8)
			p.initial_velocity_min = 260.0
			p.initial_velocity_max = 420.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
			p.color = Color("f7d58e")
		"fireflies":
			p.texture = load("res://assets/ui/glow.png")
			p.position = Vector2(960, 700)
			p.emission_rect_extents = Vector2(960, 300)
			p.amount = 26
			p.lifetime = 5.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 30.0
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.14
			p.color = Color(0.85, 1.0, 0.5)
			p.color_ramp = _fade_in_out()
		"embers":
			p.texture = load("res://assets/ui/glow.png")
			p.position = Vector2(960, 1100)
			p.amount = 40
			p.lifetime = 7.0
			p.direction = Vector2(0, -1)
			p.spread = 20.0
			p.gravity = Vector2(0, -10)
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 110.0
			p.scale_amount_min = 0.06
			p.scale_amount_max = 0.12
			p.color = Color(1.0, 0.55, 0.2)
			p.color_ramp = _fade_in_out()
		"snow":
			p.texture = load("res://assets/ui/glow.png")
			p.amount = 90
			p.lifetime = 12.0
			p.direction = Vector2(0.15, 1)
			p.spread = 15.0
			p.gravity = Vector2(4, 10)
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 90.0
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.11
			p.color = Color(1, 1, 1, 0.95)
		"stars":
			p.texture = load("res://assets/sprites/ui/item_star.png")
			p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p.position = Vector2(960, 380)
			p.emission_rect_extents = Vector2(960, 380)
			p.amount = 16
			p.lifetime = 2.6
			p.direction = Vector2(0, 1)
			p.spread = 0.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 4.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.0
			var curve := Curve.new()
			curve.add_point(Vector2(0, 0))
			curve.add_point(Vector2(0.5, 1))
			curve.add_point(Vector2(1, 0))
			p.scale_amount_curve = curve
			p.color = Color(1, 0.97, 0.75)
		_:
			p.queue_free()
			return
	_ambient.add_child(p)
	p.emitting = true


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / cols.size())
		cs.append(Color(cols[i]))
	g.offsets = offs
	g.colors = cs
	return g


static func _fade_in_out() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	return g
