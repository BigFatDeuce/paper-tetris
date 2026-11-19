extends MenuPage
## Yes / No question.

var question := "Are you sure?"
var on_yes: Callable


func _init() -> void:
	title = "SURE?"
	tab_color = "purple"
	menu_width = 300


func open() -> void:
	set_hint(question)
	menu.index = 1
	await super.open()


func build_items() -> Array:
	return [{"id": "yes", "text": "Yes"}, {"id": "no", "text": "No"}]


func activate(id: String) -> void:
	if id == "yes":
		nav.pop()
		if on_yes.is_valid():
			on_yes.call()
	else:
		nav.pop()
