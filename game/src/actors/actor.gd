class_name Actor
extends Node2D
## One paper character (Shy Guy & co). Purely decorative: walks, runs,
## jumps, dances, reacts and emotes. The node position is its feet.
## Sprites face left in the sheets; turning plays the Paper Mario style
## paper flip (horizontal squash).

signal arrived()
signal finished_sequence()

const CHAR_DIR := "res://assets/sprites/characters/"
const META_PATH := "res://data/characters_meta.json"
const POSES := {
	"idle": ["idle", "float"],
	"walk": ["walk", "wobble", "float", "idle"],
	"run": ["run", "walk", "wobble", "float"],
	"jump": ["jump", "hop", "fall", "idle", "float"],
	"fall": ["fall", "jump", "idle", "float"],
	"land": ["land", "crouch", "idle", "float"],
	"cheer": ["cheer", "dance", "salute", "wave", "signal", "hop", "flare", "jump", "aim", "idle"],
	"dance": ["dance", "dance2", "spin", "signal2", "cheer", "hop", "wobble", "flare", "idle"],
	"look_up": ["look_up", "back", "idle", "float"],
	"crouch": ["crouch", "squat", "land", "idle", "float"],
	"panic": ["flail", "dizzy", "wobble", "jump", "idle", "fall"],
	"tumble": ["tumble", "knocked", "flail", "fall", "lie"],
	"dizzy": ["dizzy", "faded", "lie", "idle"],
	"lie": ["lie", "sleep", "faded", "idle"],
	"sleep": ["sleep", "lie", "sit", "idle"],
	"spin": ["spin", "dance2", "dance", "cheer", "idle"],
	"front": ["front", "idle"],
	"sit": ["sit", "squat", "sleep", "idle"],
	"salute": ["salute", "cheer", "idle"],
}

static var _meta := {}

var key := "shyguy_red"
var px_scale := 3
var facing := -1                 # -1 left, +1 right
var speed_walk := 70.0
var speed_run := 210.0
var airborne := false            # flying characters ignore the ground
var ground_y := 0.0
var air := 0.0                   # height above the ground (jumps)
var busy := false                # running a scripted sequence
var bounds := Vector2(0, 1920)   # where it may wander (x range)
var home := Vector2.ZERO

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var body: Node2D                 # holds sprite + parts, raised by `air`
var _target_x := NAN
var _running := false
var _pose := ""
var _seq := 0
var _flip_tw: Tween
var _bubble: Node2D
var _extra_lift := 0.0           # stilts


static func meta(k: String) -> Dictionary:
	if _meta.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		_meta = v if typeof(v) == TYPE_DICTIONARY else {}
	return _meta.get(k, {})


static func make(k: String, s: int) -> Actor:
	var a := Actor.new()
	a.key = k
	a.px_scale = s
	return a


func _ready() -> void:
	var m := meta(key)
	var foot: Array = m.get("foot", [30, 45])
	var cell: Array = m.get("cell", [61, 47])
	shadow = Sprite2D.new()
	shadow.texture = preload("res://assets/ui/shadow.png")
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sw := float(cell[0]) * px_scale * 0.62 / 96.0
	shadow.scale = Vector2(sw, sw * 0.9)
	shadow.modulate = Color(1, 1, 1, 0.42)
	add_child(shadow)
	body = Node2D.new()
	add_child(body)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load(CHAR_DIR + key + "_frames.tres")
	sprite.centered = false
	sprite.offset = -Vector2(float(foot[0]), float(foot[1]))
	sprite.scale = Vector2(px_scale, px_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	ground_y = position.y
	speed_walk = 22.0 * px_scale + randf_range(-6, 6)
	speed_run = 70.0 * px_scale
	set_pose("idle")
	sprite.frame = randi() % maxi(sprite.sprite_frames.get_frame_count(sprite.animation), 1)
	_apply_facing(true)


func height_px() -> float:
	var m := meta(key)
	var foot: Array = m.get("foot", [30, 45])
	return float(foot[1]) * px_scale * 0.9 + _extra_lift


# ----------------------------------------------------------------- visuals

func has_anim(a: String) -> bool:
	return sprite.sprite_frames.has_animation(a)


func set_pose(pose: String, restart := false) -> void:
	var anim := ""
	for cand: String in POSES.get(pose, [pose]):
		if has_anim(cand):
			anim = cand
			break
	if anim == "":
		anim = "idle" if has_anim("idle") else sprite.sprite_frames.get_animation_names()[0]
	_pose = pose
	if sprite.animation != anim or restart or not sprite.is_playing():
		sprite.play(anim)


func pose() -> String:
	return _pose


func face(dir: int, instant := false) -> void:
	dir = 1 if dir > 0 else -1
	if dir == facing:
		return
	facing = dir
	_apply_facing(instant)


func face_x(x: float) -> void:
	if absf(x - position.x) > 4.0:
		face(1 if x > position.x else -1)


func _apply_facing(instant: bool) -> void:
	if _flip_tw:
		_flip_tw.kill()
	if instant:
		sprite.flip_h = facing > 0
		body.scale.x = 1.0
		return
	# the paper turn: squash to a sliver, flip, unsquash
	_flip_tw = create_tween()
	_flip_tw.tween_property(body, "scale:x", 0.05, 0.07)
	_flip_tw.tween_callback(func(): sprite.flip_h = facing > 0)
	_flip_tw.tween_property(body, "scale:x", 1.0, 0.08)


## Little paper "pop" when appearing.
func pop_in(delay := 0.0) -> void:
	body.scale = Vector2(1, 0.0)
	shadow.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(body, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shadow, "modulate:a", 0.42, 0.3)


func pop_out() -> void:
	busy = true
	_seq += 1
	var tw := create_tween()
	tw.tween_property(body, "scale:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## A few Paper Mario hearts float up from the head (a happy fan).
func hearts(count := 3) -> void:
	if not bool(Settings.get_value("particles")):
		return
	for i in count:
		var h := Sprite2D.new()
		h.texture = preload("res://assets/sprites/ui/heart.png")
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.z_index = 29
		var base := Vector2(randf_range(-18, 18), -height_px() - 10)
		h.position = base
		h.scale = Vector2.ZERO
		body.add_child(h)
		var sway := randf_range(-30, 30)
		var tw := h.create_tween()
		tw.tween_interval(i * 0.18)
		tw.tween_property(h, "scale", Vector2(2.5, 2.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "position", base + Vector2(sway, -110), 1.0).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(h, "modulate:a", 0.0, 0.4).set_delay(0.6)
		tw.tween_callback(h.queue_free)


func emote(text: String, dur := 1.3) -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	var b := Node2D.new()
	b.position = Vector2(0, -height_px() - 26)
	b.z_index = 30
	var bg := Sprite2D.new()
	bg.texture = preload("res://assets/sprites/ui/cloud.png")   # Paper Mario's thought cloud
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.scale = Vector2(2.6, 2.6)
	bg.offset = Vector2(0, -24)
	b.add_child(bg)
	var l := UIKit.label(text, 4, UIKit.RED if text == "!" else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(80, 64)
	l.position = Vector2(-40, -94)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	body.add_child(b)
	_bubble = b
	b.scale = Vector2(0.2, 0.2)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(b, "scale", Vector2(0.1, 0.1), 0.12)
	tw.tween_callback(b.queue_free)


## Adds a part sprite (balloon, stilt...) to the body. Returns it.
func add_part(tex: Texture2D, offset: Vector2, behind := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(px_scale, px_scale)
	s.position = offset
	body.add_child(s)
	if behind:
		body.move_child(s, 0)
	return s


func set_stilts(tex: Texture2D) -> void:
	var h := tex.get_height() * px_scale
	_extra_lift = h - 6.0 * px_scale
	var s := add_part(tex, Vector2(0, -h * 0.5), true)
	s.name = "Stilt"
	sprite.position.y = -_extra_lift


# --------------------------------------------------------------- movement

func _process(delta: float) -> void:
	if not is_nan(_target_x):
		var spd := speed_run if _running else speed_walk
		var dx := _target_x - position.x
		if absf(dx) <= spd * delta:
			position.x = _target_x
			_target_x = NAN
			if air <= 0.0 and not airborne:
				set_pose("idle")
			arrived.emit()
		else:
			position.x += signf(dx) * spd * delta
	body.position.y = -air
	if shadow:
		var k := clampf(1.0 - air / 260.0, 0.35, 1.0)
		shadow.scale.x = absf(shadow.scale.y / 0.9) * k
		shadow.visible = not airborne


func stop() -> void:
	_target_x = NAN
	arrived.emit()


## Moves to x (awaitable: `await actor.go_to(x)`).
func go_to(x: float, run := false) -> void:
	x = clampf(x, bounds.x, bounds.y)
	if absf(x - position.x) < 2.0:
		return
	_running = run
	face_x(x)
	set_pose("run" if run else "walk")
	_target_x = x
	await arrived


## Moves without bounds (entering / leaving the screen).
func go_to_free(x: float, run := false) -> void:
	_running = run
	face_x(x)
	set_pose("run" if run else "walk")
	_target_x = x
	await arrived


var _jumping := false


func jump(height := 70.0, dur := 0.55) -> void:
	# every await below needs the tree: outside it get_tree() is null, the
	# await returns at once and a loop would spin forever (frozen game)
	while _jumping and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_jumping = true
	var tw := create_tween()
	set_pose("jump", true)
	tw.tween_method(func(t: float):
		air = 4.0 * height * t * (1.0 - t)
		if t > 0.5 and _pose == "jump":
			set_pose("fall"), 0.0, 1.0, dur)
	await tw.finished
	air = 0.0
	_jumping = false
	set_pose("land")
	if is_inside_tree():
		await get_tree().create_timer(0.1, false).timeout


func hop() -> void:
	await jump(26.0 + px_scale * 4.0, 0.32)


func wait(t: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(t, false).timeout


## Starts a new sequence: any previous one stops at its next step.
func begin_sequence() -> int:
	_seq += 1
	busy = true
	if not is_nan(_target_x):
		# release whoever awaits the previous walk; it sees it is stale
		_target_x = NAN
		arrived.emit()
	return _seq


func is_current(id: int) -> bool:
	return id == _seq and is_inside_tree()


func end_sequence(id: int) -> void:
	if id == _seq:
		busy = false
		finished_sequence.emit()
