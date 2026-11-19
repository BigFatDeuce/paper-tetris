class_name PaperWindow
extends Control
## A Paper Mario style window: cream paper with a dark rim, a soft drop
## shadow and an optional coloured title tab. Children added to `content`
## are laid out inside the paper margins.

@export var title := "":
	set(v):
		title = v
		if is_inside_tree():
			_update_tab()
@export_enum("red", "gold", "blue", "green", "purple") var tab_color := "red":
	set(v):
		tab_color = v
		if is_inside_tree():
			_update_tab()
@export_enum("paper", "light", "night") var style := "paper":
	set(v):
		style = v
		if _body:
			_body.texture = _style_texture()
@export var padding := Vector4(30, 30, 30, 26)   # left, top, right, bottom
@export var shadow_offset := Vector2(10, 12)

var content: MarginContainer
var _shadow: NinePatchRect
var _body: NinePatchRect
var _tab: NinePatchRect
var _tab_label: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_shadow = NinePatchRect.new()
	_shadow.texture = UIKit.TEX_SHADOW
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_shadow.set_patch_margin(m, 56)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.show_behind_parent = true
	add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)
	_body = NinePatchRect.new()
	_body.texture = _style_texture()
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_body.set_patch_margin(m, 34)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	content = MarginContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content, false, Node.INTERNAL_MODE_FRONT)
	_tab = NinePatchRect.new()
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for m in [SIDE_LEFT, SIDE_RIGHT]:
		_tab.set_patch_margin(m, 22)
	for m in [SIDE_TOP, SIDE_BOTTOM]:
		_tab.set_patch_margin(m, 20)
	add_child(_tab, false, Node.INTERNAL_MODE_FRONT)
	_tab_label = UIKit.label("", 3, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tab.add_child(_tab_label)
	_tab_label.minimum_size_changed.connect(_layout)   # e.g. another language
	resized.connect(_layout)
	_update_tab()
	_layout()


func _style_texture() -> Texture2D:
	match style:
		"light": return UIKit.TEX_PANEL_LIGHT
		"night": return UIKit.TEX_PANEL_NIGHT
	return UIKit.TEX_PANEL


func _update_tab() -> void:
	if _tab == null:
		return
	_tab.visible = title != ""
	_tab.texture = UIKit.TABS.get(tab_color, UIKit.TABS["red"])
	_tab_label.text = title
	_layout()


func _layout() -> void:
	if _body == null:
		return
	_body.position = Vector2.ZERO
	_body.size = size
	_shadow.position = shadow_offset - Vector2(28, 28)
	_shadow.size = size + Vector2(56, 56)
	content.position = Vector2(padding.x, padding.y)
	content.size = size - Vector2(padding.x + padding.z, padding.y + padding.w)
	if title != "":
		var tw := maxf(_tab_label.get_minimum_size().x + 56, 150)
		_tab.size = Vector2(tw, 58)
		_tab.position = Vector2((size.x - tw) * 0.5, -34)
		_tab_label.position = Vector2(0, 2)
		_tab_label.size = _tab.size


## Content height needed for a given inner size.
func fit_to_content() -> void:
	var m := content.get_combined_minimum_size()
	size = Vector2(maxf(size.x, m.x + padding.x + padding.z), m.y + padding.y + padding.w)


func pop_in(delay := 0.0) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	rotation = deg_to_rad(-4)
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14).set_delay(delay)
	_tween.tween_property(self, "rotation", 0.0, 0.36).set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if delay <= 0.0:
		Audio.sfx("window_open")


func pop_out(free_after := false) -> void:
	pivot_offset = size * 0.5
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.chain().tween_callback(func():
		visible = false
		if free_after:
			queue_free())
	Audio.sfx("window_close")
