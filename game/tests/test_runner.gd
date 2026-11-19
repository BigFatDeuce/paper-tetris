extends Node
## Headless test runner:
##   Godot --headless --path game res://tests/test_runner.tscn
## Runs every test_* method of the suites below, prints a report and quits
## with exit code 0 (all passed) or 1.

const SUITES := [
	preload("res://tests/test_engine.gd"),
	preload("res://tests/test_modes.gd"),
	preload("res://tests/test_systems.gd"),
	preload("res://tests/test_world.gd"),
]

var failures := 0
var passed := 0


func _ready() -> void:
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	for suite_script: GDScript in SUITES:
		var suite: Object = suite_script.new()
		if suite is Node:
			add_child(suite)
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			suite.set("_failed", false)
			suite.set("_messages", [])
			var ret: Variant = suite.call(name)
			if ret is Object and ret.has_method("is_valid"):
				await ret
			if suite.get("_failed"):
				failures += 1
				print("  FAIL  %s.%s" % [suite_script.resource_path.get_file(), name])
				for msg: String in suite.get("_messages"):
					print("        ", msg)
			else:
				passed += 1
				print("  ok    %s" % name)
		if suite is Node:
			suite.queue_free()
	print("\n%d passed, %d failed (%d ms)" % [passed, failures, Time.get_ticks_msec() - t0])
	get_tree().quit(1 if failures > 0 else 0)
