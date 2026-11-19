extends Node
## User settings, persisted in user://settings.cfg.

signal changed(key: String)

const PATH := "user://settings.cfg"
var path := PATH

const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.75,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"vsync": true,
	"ghost": true,
	"hold": true,
	"next_count": 5,
	"das": 0.167,
	"arr": 0.033,
	"soft_drop_factor": 20.0,
	"screen_shake": 2,       # 0 off, 1 light, 2 full
	"particles": true,
	"crowd": 2,            # 0 none, 1 calm, 2 lively
	"grid": true,
	"music_choice": "stage",
	"show_fps": false,
	"language": "auto",
	"last_mode": "marathon",
	"last_level": 1,
	"last_stage": "auto",
	"practice_gravity": true,
	"practice_level_up": false,
	"sfx_overrides": {},
	"bindings": {},
}

var values := {}
var _loading := false


func _ready() -> void:
	values = DEFAULTS.duplicate(true)
	load_settings()
	apply_display()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant, save := true) -> void:
	values[key] = value
	if key in ["fullscreen", "vsync"]:
		apply_display()
	if save and not _loading:
		save_settings()
	changed.emit(key)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	_loading = true
	for key: String in DEFAULTS.keys():
		if cfg.has_section_key("settings", key):
			var v: Variant = cfg.get_value("settings", key)
			if key == "screen_shake" and typeof(v) == TYPE_BOOL:
				v = 2 if v else 0   # older saves stored On / Off
			if typeof(v) == typeof(DEFAULTS[key]) or (typeof(DEFAULTS[key]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[key] = v
	_loading = false


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.save(path)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fs: bool = values.get("fullscreen", false)
	var mode := DisplayServer.window_get_mode()
	if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs and (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if values.get("vsync", true) else DisplayServer.VSYNC_DISABLED)


func reset_to_defaults() -> void:
	var keep := {"bindings": values.get("bindings", {}), "last_mode": values.get("last_mode"), "language": values.get("language")}
	values = DEFAULTS.duplicate(true)
	values.merge(keep, true)
	save_settings()
	apply_display()
	for k: String in values.keys():
		changed.emit(k)
