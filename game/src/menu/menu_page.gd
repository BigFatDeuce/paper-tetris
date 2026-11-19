class_name MenuPage
extends PaperWindow
## One window of the menu stack: a ListMenu plus an optional hint line.
## Subclasses override build_items() / activate() / step() / back().

var nav: Node            # the MenuNav that owns the stack (main_menu.gd)
var menu: ListMenu
var hint: Label
var extra: VBoxContainer  # free area under the list for custom content
var center_on := Vector2(960, 640)
var menu_width := 460
var _fitted := Vector2.ZERO


func _ready() -> void:
	super._ready()
	padding = Vector4(36, 46, 36, 30)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	content.add_child(vb)
	menu = ListMenu.new()
	menu.min_width = menu_width
	menu.active = false
	vb.add_child(menu)
	extra = VBoxContainer.new()
	extra.add_theme_constant_override("separation", 6)
	vb.add_child(extra)
	hint = UIKit.label("", 2, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.visible = false
	vb.add_child(hint)
	menu.activated.connect(activate)
	menu.value_step.connect(step)
	menu.cancelled.connect(back)
	menu.moved.connect(moved)
	visible = false


## Called by the nav when the page is shown.
func open() -> void:
	menu.set_items(build_items(), true)
	moved(menu.current_id())
	await relayout()
	pop_in()
	menu.set_active(true)


func close() -> void:
	menu.set_active(false)
	pop_out()


func relayout() -> void:
	await get_tree().process_frame
	_fit()


func _fit() -> void:
	size = Vector2.ZERO
	fit_to_content()
	_fitted = content.get_combined_minimum_size()
	position = (center_on - size * 0.5).round()
	position.y = clampf(position.y, 60.0, 1080.0 - size.y - 30.0)
	pivot_offset = size * 0.5


func _process(_delta: float) -> void:
	# content changed (hint, info text...): grow / shrink the paper
	if visible and content and content.get_combined_minimum_size() != _fitted:
		_fit()


func refresh() -> void:
	var keep := menu.index
	menu.set_items(build_items(), true)
	menu.index = clampi(keep, 0, maxi(menu.items.size() - 1, 0))
	menu.set_active(menu.active)


func set_hint(text: String) -> void:
	hint.text = text
	hint.visible = text != ""
	hint.custom_minimum_size.x = menu_width


# ------------------------------------------------------------ overridables

func build_items() -> Array:
	return []


func activate(_id: String) -> void:
	pass


func step(_id: String, _dir: int) -> void:
	pass


func moved(_id: String) -> void:
	pass


func back() -> void:
	nav.pop()
