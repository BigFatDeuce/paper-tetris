extends Node
## Stage assets and the decorative Shy Guy crowd (director).

var _failed := false
var _messages: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_messages.append(msg)


func test_stage_assets() -> void:
	for id: String in StageLibrary.ids():
		var folder := StageLibrary.folder(id)
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + "layers.json"))
		check(typeof(meta) == TYPE_DICTIONARY, "%s: layers.json readable" % id)
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		var layers: Array = meta.get("layers", [])
		check(layers.size() >= 2, "%s: sky + at least one rendered layer" % id)
		for l: Dictionary in layers:
			var tex: Texture2D = load(folder + str(l["file"]))
			check(tex != null, "%s: %s loads" % [id, l["file"]])
		var sky: Texture2D = load(folder + str(layers[0]["file"]))
		if sky:
			check(sky.get_size() == Vector2(1920, 1080), "%s: sky fills the screen" % id)


func test_director_crowd() -> void:
	var old_crowd: Variant = Settings.get_value("crowd")
	Settings.set_value("crowd", 2, false)
	var d := Director.new()
	add_child(d)
	d.setup("meadow", [Rect2(40, 930, 380, 110), Rect2(1500, 930, 380, 110)], [Rect2(1224, 152, 270, 460)])
	check(d.actors.size() == 6, "lively crowd = 6 actors (got %d)" % d.actors.size())
	# every game event the crowd listens to, twice, must be harmless
	var events := [
		[&"game_start", {}], [&"lines", {"lines": 1}], [&"lines", {"lines": 3}], [&"tetris", {}],
		[&"tspin", {}], [&"combo", {"combo": 4}], [&"perfect", {}], [&"level_up", {"level": 3}],
		[&"hard_drop", {"rows": 12, "x": 4}], [&"lock", {"type": 2, "x": 3}],
		[&"danger", {"on": true}], [&"danger", {"on": false}], [&"hold", {}],
		[&"menu_select", {}], [&"menu_back", {}], [&"game_clear", {}], [&"new_record", {}],
		[&"game_over", {}],
	]
	for i in 2:
		for ev: Array in events:
			Events.emit_event(ev[0], ev[1])
			await get_tree().process_frame
	check(d.mood == "sad", "game over leaves the crowd sad")
	await get_tree().create_timer(0.6).timeout
	# a stage change sends the troupe off and brings a new one in
	d.change_stage("snow")
	await get_tree().create_timer(1.4).timeout
	check(d.stage_id == "snow", "stage switched")
	check(d.actors.size() == 6, "new troupe spawned (got %d)" % d.actors.size())
	Events.emit_event(&"tetris", {})
	await get_tree().create_timer(0.3).timeout
	for a: Actor in d.actors:
		check(a.has_meta("entering") or (a.position.x > -200 and a.position.x < 2120), "actor near the stage")
	# the crowd setting is live
	Settings.set_value("crowd", 0, false)
	check(d.actors.is_empty(), "crowd None removes everyone")
	Settings.set_value("crowd", 3, false)
	check(d.actors.size() == 10, "party crowd = 10 actors (got %d)" % d.actors.size())
	Settings.set_value("crowd", old_crowd, false)
	d.queue_free()
	await get_tree().process_frame


## Regression (Android freeze on a brown iris): a scene change takes the
## director out of the tree a frame before freeing it. Its animation loops
## must stop then: in release builds get_tree() is null, the await returns at
## once and the loop used to spin forever.
func test_director_loops_stop_outside_tree() -> void:
	var d := Director.new()
	add_child(d)
	d.setup("stars", [Rect2(40, 930, 1840, 110)], [])
	var before := d.get_child_count()
	d._flyby()
	var flyer: Node = d.get_child(d.get_child_count() - 1)
	check(d.get_child_count() == before + 1 and flyer is Actor, "flyby actor spawned")
	await get_tree().process_frame
	remove_child(d)
	for i in 3:
		await get_tree().process_frame
	check(not is_instance_valid(flyer) or flyer.is_queued_for_deletion(), "flyby loop ended once the director left the tree")
	d.free()


func test_actor_sequences() -> void:
	var a := Actor.make("shyguy_red", 3)
	a.position = Vector2(300, 1000)
	add_child(a)
	var first := a.begin_sequence()
	a.go_to(600)
	var second := a.begin_sequence()   # interrupts the walk
	check(not a.is_current(first), "older sequence is stale")
	check(a.is_current(second), "newest sequence is current")
	a.end_sequence(second)
	check(not a.busy, "ending the current sequence frees the actor")
	a.face(-1, true)
	check(not a.sprite.flip_h, "facing left shows the sheet as drawn")
	a.face(1, true)
	check(a.sprite.flip_h, "facing right flips the left-facing sheet")
	a.queue_free()
	await get_tree().process_frame


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	return out


func test_every_script_and_scene_loads() -> void:
	var scripts := _files("res://src", ".gd")
	check(scripts.size() > 30, "found the scripts (%d)" % scripts.size())
	for p: String in scripts:
		var s: GDScript = load(p)
		check(s != null and s.can_instantiate(), "%s compiles" % p)
	for p: String in _files("res://src", ".tscn"):
		var sc: PackedScene = load(p)
		check(sc != null and sc.can_instantiate(), "%s loads" % p)


func test_translations() -> void:
	var fr: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/fr.json"))
	check(typeof(fr) == TYPE_DICTIONARY, "fr.json readable")
	if typeof(fr) != TYPE_DICTIONARY:
		return
	var re := RegEx.create_from_string("%[0-9.]*[sdf%]")
	for k: String in fr:
		if k.begins_with("//"):
			continue
		var a := re.search_all(k).map(func(m): return m.get_string())
		var b := re.search_all(str(fr[k])).map(func(m): return m.get_string())
		check(a == b, "placeholders match for %s" % k)
	var old := str(Settings.get_value("language"))
	Settings.set_value("language", "fr", false)
	check(tr("Play") == "Jouer", "French is live")
	check(tr("LEVEL %d") % 3 == "NIVEAU 3", "formatted French")
	Settings.set_value("language", "en", false)
	check(tr("Play") == "Play", "back to English")
	Settings.set_value("language", old, false)
