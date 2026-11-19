extends TestBase
## Input auto-repeat, records persistence, settings, rebinding, data files.


func test_das_arr() -> void:
	var r := AutoRepeat.new()
	r.das = 0.167
	r.arr = 0.033
	eq(r.press(-1), 1, "first press moves once")
	eq(r.update(0.1), 0, "no repeat before DAS")
	var n := r.update(0.08)
	eq(n, 1, "DAS reached: one repeat")
	eq(r.update(0.066), 2, "then ARR repeats")
	r.press(1)
	eq(r.direction(), 1, "last pressed direction wins")
	r.release(1)
	eq(r.direction(), -1, "falls back to the held direction")
	eq(r.update(0.1), 0, "fallback direction recharges DAS")
	r.release(-1)
	eq(r.direction(), 0, "nothing held")
	r.arr = 0.0
	r.press(1)
	eq(r.update(0.2), AutoRepeat.INSTANT, "ARR 0 = instant to the wall")


func test_records_ordering() -> void:
	var path := "user://test_records.json"
	var sd: Node = SaveData
	var old_path: String = sd.path
	var old_data: Dictionary = sd.data.duplicate(true)
	sd.path = path
	sd.data = sd._empty()
	eq(sd.submit("marathon", {"score": 1000, "lines": 10}), 0, "first record rank 0")
	eq(sd.submit("marathon", {"score": 5000, "lines": 40}), 0, "better score takes rank 0")
	eq(sd.submit("marathon", {"score": 3000, "lines": 30}), 1, "middle score rank 1")
	eq(sd.submit("sprint", {"time": 80.0, "lines": 40}), 0, "sprint rank 0")
	eq(sd.submit("sprint", {"time": 60.5, "lines": 40}), 0, "faster sprint is better")
	eq(sd.submit("sprint", {"time": 95.0, "lines": 40}), 2, "slowest sprint rank 2")
	for i in 12:
		sd.submit("ultra", {"score": i * 100})
	eq(sd.records("ultra").size(), SaveData.MAX_ENTRIES, "top 10 only")
	eq(sd.submit("ultra", {"score": 50}), -1, "too low for the table")
	# reload from disk
	sd.load_data()
	eq(int(sd.best("marathon")["score"]), 5000, "records survive a reload")
	check(sd.best("marathon")["lines"] is int, "reloaded counts stay integers (no '40.0')")
	eq(float(sd.best("sprint")["time"]), 60.5, "sprint best survives a reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sd.path = old_path
	sd.data = old_data


func test_settings_roundtrip() -> void:
	var s: Node = Settings
	var old_path: String = s.path
	var old_values: Dictionary = s.values.duplicate(true)
	s.path = "user://test_settings.cfg"
	s.set_value("music_volume", 0.33)
	s.set_value("ghost", false)
	s.values = s.DEFAULTS.duplicate(true)
	s.load_settings()
	check(absf(float(s.get_value("music_volume")) - 0.33) < 0.0001, "volume saved")
	eq(s.get_value("ghost"), false, "ghost option saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.path = old_path
	s.values = old_values


func test_rebind() -> void:
	var s: Node = Settings
	var old_path: String = s.path
	var old_values: Dictionary = s.values.duplicate(true)
	s.path = "user://test_settings.cfg"
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	Controls.rebind("game_hold", ev, 0)
	var probe := InputEventKey.new()
	probe.physical_keycode = KEY_J
	check(InputMap.action_has_event("game_hold", probe), "J now holds")
	# stealing a key from another action
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_SPACE
	Controls.rebind("game_hold", ev2, 1)
	var probe2 := InputEventKey.new()
	probe2.physical_keycode = KEY_SPACE
	check(not InputMap.action_has_event("game_hard_drop", probe2), "space removed from hard drop")
	check(InputMap.action_has_event("game_hold", probe2), "space now on hold")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.path = old_path
	s.values = old_values
	Controls.apply_bindings()


func test_data_files() -> void:
	var music: Dictionary = Audio.music_catalog
	check(music.size() >= 10, "music catalogue loaded (%d)" % music.size())
	for id: String in music.keys():
		check(ResourceLoader.exists(music[id]["file"]), "music file exists: %s" % id)
		check(float(music[id].get("duration", 0.0)) > Audio.TRACK_XFADE * 2.0, "track %s longer than its crossfades" % id)
	for id: String in Audio.sfx_catalog.keys():
		check(ResourceLoader.exists(Audio.sfx_catalog[id]["file"]), "sfx file exists: %s" % id)
	for st: String in StageLibrary.ids():
		var d: Dictionary = StageLibrary.get_stage(st)
		check(music.has(d["music"]), "stage %s music exists" % st)
		check(music.has(d.get("music2", "")), "stage %s second theme exists" % st)
