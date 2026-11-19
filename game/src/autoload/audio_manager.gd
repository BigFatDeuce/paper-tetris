extends Node
## Music (two players, crossfades, seamless loops from data/music.json) and
## sound effects (voice pool, data/sfx.json). Separate Music / SFX buses.

const MUSIC_DATA := "res://data/music.json"
const SFX_DATA := "res://data/sfx.json"
const SFX_VOICES := 14

var music_catalog := {}
var sfx_catalog := {}
var current_music := ""

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade_tweens: Array = [null, null]
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _streams := {}
var _sfx_streams := {}
var _lowpass: AudioEffectLowPassFilter
var _music_bus := 0
var _sfx_bus := 0
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	music_catalog = _load_json(MUSIC_DATA)
	sfx_catalog = _load_json(SFX_DATA)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for i in SFX_VOICES:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_sfx_players.append(s)
	apply_volumes()
	Settings.changed.connect(_on_setting)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music_bus = AudioServer.get_bus_index("Music")
	_sfx_bus = AudioServer.get_bus_index("SFX")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 900.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)


func _on_setting(key: String) -> void:
	if key.ends_with("_volume"):
		apply_volumes()


static func _lin_to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else 20.0 * log(v) / log(10.0)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _lin_to_db(float(Settings.get_value("master_volume"))))
	AudioServer.set_bus_volume_db(_music_bus, _lin_to_db(float(Settings.get_value("music_volume"))))
	AudioServer.set_bus_volume_db(_sfx_bus, _lin_to_db(float(Settings.get_value("sfx_volume"))))


# ---------------------------------------------------------------- music

func music_title(id: String) -> String:
	return music_catalog.get(id, {}).get("title", id)


func music_ids() -> Array:
	return music_catalog.keys()


func _music_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var info: Dictionary = music_catalog.get(id, {})
	if info.is_empty() or not ResourceLoader.exists(info["file"]):
		return null
	var st: AudioStream = load(info["file"])
	if st is AudioStreamOggVorbis:
		var ogg := st as AudioStreamOggVorbis
		ogg.loop = bool(info.get("loop", true))
		ogg.loop_offset = float(info.get("loop_offset", 0.0))
	_streams[id] = st
	return st


## Crossfades to music `id`. Does nothing if it is already playing.
func play_music(id: String, fade := 1.0, restart := false) -> void:
	if id == current_music and not restart and _players[_active].playing:
		return
	var st := _music_stream(id)
	if st == null:
		push_warning("music not found: %s" % id)
		return
	current_music = id
	var old := _active
	_active = 1 - _active
	var p := _players[_active]
	p.stream = st
	p.pitch_scale = 1.0
	p.volume_db = -40.0 if fade > 0.0 else 0.0
	p.play()
	_fade(_active, 0.0, fade)
	_fade(old, -60.0, fade, true)


func stop_music(fade := 1.0) -> void:
	current_music = ""
	_fade(_active, -60.0, fade, true)


func _fade(idx: int, to_db: float, dur: float, stop_after := false) -> void:
	if _fade_tweens[idx]:
		(_fade_tweens[idx] as Tween).kill()
	var p := _players[idx]
	if dur <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, dur).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)
	_fade_tweens[idx] = tw


## Muffles the music (pause menu).
func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_music_bus, 0, on)


func set_music_pitch(pitch: float) -> void:
	_players[_active].pitch_scale = pitch


# ------------------------------------------------------------------- sfx

func _sfx_entry(name: String) -> Dictionary:
	var over: Dictionary = Settings.get_value("sfx_overrides")
	var e: Dictionary = sfx_catalog.get(name, {}).duplicate()
	if over.has(name):
		e["file"] = over[name]
	return e


func _sfx_stream(path: String) -> AudioStream:
	if _sfx_streams.has(path):
		return _sfx_streams[path]
	if not ResourceLoader.exists(path):
		_sfx_streams[path] = null
		return null
	var st: AudioStream = load(path)
	_sfx_streams[path] = st
	return st


## Plays a named sound effect. `pitch` multiplies the catalogue pitch.
func sfx(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var e := _sfx_entry(name)
	if e.is_empty():
		return
	var now := Time.get_ticks_msec()
	# avoid stacking the very same sound in the same frame
	if _last_play.get(name, -1000) > now - 25 and not e.get("stack", false):
		return
	_last_play[name] = now
	play_file(str(e["file"]), float(e.get("pitch", 1.0)) * pitch * _variation(e),
		float(e.get("volume_db", 0.0)) + volume_db)


func _variation(e: Dictionary) -> float:
	var v := float(e.get("pitch_var", 0.0))
	return 1.0 + randf_range(-v, v) if v > 0.0 else 1.0


func play_file(path: String, pitch := 1.0, volume_db := 0.0) -> void:
	var st := _sfx_stream(path)
	if st == null:
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = st
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()
