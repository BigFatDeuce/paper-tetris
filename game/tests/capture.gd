extends Node
## Debug helper: opens a scene, optionally plays a scripted demo and saves
## screenshots. Usage (rendered, not headless):
##   godot --path . res://tests/capture.tscn -- scene=res://src/game/game.tscn shots=2.5,6 out=C:/tmp/shot demo=1 mode=marathon

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	# test runs keep their scores out of the player's records
	SaveData.path = "user://capture_records.json"
	SaveData.load_data()
	# ...and their settings out of the player's options
	Settings.path = "user://capture_settings.cfg"
	Settings.values = Settings.DEFAULTS.duplicate(true)
	Settings.load_settings()
	if args.has("lang"):
		Settings.set_value("language", args["lang"], false)
	# trailer recording: the music is laid over afterwards in one piece
	if args.get("music", "1") == "0":
		Settings.set_value("music_volume", 0.0, false)
	for k in ["crowd", "screen_shake"]:
		if args.has(k):
			Settings.set_value(k, int(args[k]), false)
	var helper := preload("res://tests/capture_helper.gd").new()
	helper.args = args
	helper.name = "CaptureHelper"
	get_tree().root.add_child.call_deferred(helper)
	var p := {}
	for k in ["mode", "stage", "start_level", "open"]:
		if args.has(k):
			p[k] = args[k] if k != "start_level" else int(args[k])
	if args.has("seed"):
		p["seed"] = int(args["seed"])
	Router.params = p
	get_tree().change_scene_to_file.call_deferred(str(args.get("scene", "res://src/boot/boot.tscn")))
