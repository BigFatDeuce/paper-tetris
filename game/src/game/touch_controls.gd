class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets, made of the N64 buttons of
## Paper Mario: a floating stick on the left (move, soft drop), C-down (hard
## drop), A / B (rotations), Z (hold) and a PAUSE tab. Multi-touch; drives the
## same input actions as the keyboard and gamepad. Shown once the screen is
## touched, hidden again when a key or a gamepad is used.

const UI := "res://assets/sprites/ui/"
const STICK_ZONE := Rect2(0, 330, 560, 750)
const STICK_HOME := Vector2(250, 840)
const DEAD := 34.0
const PX := 5.0

## id -> [centre, radius, action, sprite up, sprite down]
var _buttons := {}
var _sprites := {}
var _touch_owner := {}        # touch index -> button id or "stick"
var _stick_origin := STICK_HOME
var _stick_dir := Vector2i.ZERO
var _stick_base: Sprite2D
var _stick: Sprite2D
var _pause_label: Label


func _ready() -> void:
	layer = 30
	_stick_base = _sprite("touch_stick_top", STICK_HOME, PX)
	_stick_base.modulate.a = 0.55
	_stick = _sprite("touch_stick_up", STICK_HOME + Vector2(0, -40), PX)
	_button("hard", Vector2(1600, 690), "game_hard_drop", "touch_c")
	_button("cw", Vector2(1790, 830), "game_rotate_cw", "touch_a")
	_button("ccw", Vector2(1610, 950), "game_rotate_ccw", "touch_b")
	_button("hold", Vector2(1800, 560), "game_hold", "touch_z", 7.0)
	_pause_label = UIKit.label("PAUSE", 3, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_pause_label.size = Vector2(200, 70)
	_pause_label.position = Vector2(20, 18)
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_pause_label)
	_buttons["pause"] = [Vector2(120, 53), 80.0, "game_pause"]
	visible = Controls.using_touch
	Controls.device_changed.connect(func(_pad: bool): _sync_visibility())
	Controls.touch_changed.connect(_sync_visibility)


func _sync_visibility() -> void:
	var v := Controls.using_touch
	if v != visible:
		visible = v
		if not v:
			_release_all()


func _sprite(file: String, pos: Vector2, px: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(UI + file + ".png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.scale = Vector2(px, px)
	add_child(s)
	return s


func _button(id: String, pos: Vector2, action: String, art: String, px := PX) -> void:
	var up := art + ("_up" if ResourceLoader.exists(UI + art + "_up.png") else "")
	var down := art + ("_down" if ResourceLoader.exists(UI + art + "_down.png") else "")
	var s := _sprite(up, pos, px)
	s.modulate.a = 0.9
	_sprites[id] = s
	var r := maxf(s.texture.get_width(), s.texture.get_height()) * px * 0.55
	_buttons[id] = [pos, r, action, load(UI + up + ".png"), load(UI + down + ".png")]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if not Controls.using_touch:
			Controls.set_touch(true)
		if not visible:
			return
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and visible:
		var d := event as InputEventScreenDrag
		if _touch_owner.get(d.index, "") == "stick":
			_stick_move(d.position)
			get_viewport().set_input_as_handled()


func _touch_down(index: int, pos: Vector2) -> void:
	for id: String in _buttons:
		var b: Array = _buttons[id]
		if pos.distance_to(b[0]) <= b[1]:
			_touch_owner[index] = id
			Input.action_press(b[2])
			if _sprites.has(id):
				(_sprites[id] as Sprite2D).texture = b[4]
			return
	if STICK_ZONE.has_point(pos):
		_touch_owner[index] = "stick"
		_stick_origin = pos
		_stick_base.position = pos
		_stick_move(pos)


func _touch_up(index: int) -> void:
	var id: String = _touch_owner.get(index, "")
	_touch_owner.erase(index)
	if id == "stick":
		_set_stick(Vector2i.ZERO)
		_stick_base.position = STICK_HOME
		_stick_origin = STICK_HOME
	elif _buttons.has(id):
		var b: Array = _buttons[id]
		# another finger may still hold the same button
		if not _touch_owner.values().has(id):
			Input.action_release(b[2])
			if _sprites.has(id):
				(_sprites[id] as Sprite2D).texture = b[3]


func _stick_move(pos: Vector2) -> void:
	var v := pos - _stick_origin
	var dir := Vector2i.ZERO
	if v.length() > DEAD:
		if absf(v.x) >= absf(v.y) * 0.8:
			dir.x = signi(int(v.x))
		elif v.y > 0:
			dir.y = 1
	_set_stick(dir)


func _set_stick(dir: Vector2i) -> void:
	if dir == _stick_dir:
		_place_stick()
		return
	_stick_dir = dir
	for pair: Array in [["game_left", dir.x < 0], ["game_right", dir.x > 0], ["game_soft_drop", dir.y > 0]]:
		if pair[1]:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])
	_place_stick()


func _place_stick() -> void:
	var base := _stick_base.position
	if _stick_dir.x != 0:
		_stick.texture = load(UI + "touch_stick_tilt.png")
		_stick.flip_h = _stick_dir.x > 0
		_stick.position = base + Vector2(-_stick_dir.x * -30, -30)
		_stick.scale = Vector2(PX, PX)
	elif _stick_dir.y > 0:
		_stick.texture = load(UI + "touch_stick_up.png")
		_stick.flip_h = false
		_stick.position = base + Vector2(0, -12)
		_stick.scale = Vector2(PX, PX * 0.8)
	else:
		_stick.texture = load(UI + "touch_stick_up.png")
		_stick.flip_h = false
		_stick.position = base + Vector2(0, -40)
		_stick.scale = Vector2(PX, PX)


func _release_all() -> void:
	for id: String in _buttons:
		Input.action_release(_buttons[id][2])
		if _sprites.has(id):
			(_sprites[id] as Sprite2D).texture = _buttons[id][3]
	_touch_owner.clear()
	_set_stick(Vector2i.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release_all()
