extends Node
## First scene: applies display settings, then opens the title screen.

func _ready() -> void:
	Settings.apply_display()
	await get_tree().process_frame
	Router.go("res://src/menu/main_menu.tscn", {"intro": true}, "none")
