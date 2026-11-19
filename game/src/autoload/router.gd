extends Node
## Scene changes with storybook-style iris transitions (circle or star).

signal scene_changed(path: String)

const IRIS_SHADER := preload("res://src/ui/shaders/iris.gdshader")

var params := {}
var busy := false
var current_path := ""

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _fps: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = IRIS_SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_rect.material = _mat
	_rect.visible = false
	_layer.add_child(_rect)
	_fps = Label.new()
	_fps.position = Vector2(16, 10)
	UIKit.style_label(_fps, 2, Color.WHITE, true)
	_fps.visible = false
	_layer.add_child(_fps)


func _process(_delta: float) -> void:
	var on := bool(Settings.get_value("show_fps"))
	_fps.visible = on
	if on:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


## Changes scene. style: "circle", "star" or "none".
func go(path: String, p: Dictionary = {}, style := "circle", center := Vector2(0.5, 0.5)) -> void:
	if busy:
		return
	busy = true
	params = p
	var shape := 1 if style == "star" else 0
	_mat.set_shader_parameter("shape", shape)
	_mat.set_shader_parameter("center", center)
	if style != "none":
		_rect.visible = true
		_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		Audio.sfx("transition_close")
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_method(_set_progress, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		await get_tree().create_timer(0.08, true, false, true).timeout
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("cannot open scene %s" % path)
	current_path = path
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit(path)
	if style != "none":
		_mat.set_shader_parameter("center", Vector2(0.5, 0.5))
		Audio.sfx("transition_open")
		var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw2.tween_method(_set_progress, 1.0, 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw2.finished
		_rect.visible = false
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


## Android back button / gesture: pauses a game, otherwise acts as Cancel.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var scene := get_tree().current_scene
		var action := "game_pause" if scene and scene.get("pause_menu") != null and not get_tree().paused else "ui_cancel"
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
