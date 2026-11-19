class_name GameRules
extends RefCounted
## Parameters of one game. Every mode shares the exact same Tetris rules:
## only goals and starting parameters change.

enum Mode { MARATHON, SPRINT, ULTRA, ENDLESS, PRACTICE }

const MODE_IDS := ["marathon", "sprint", "ultra", "endless", "practice"]
const MODE_NAMES := ["Marathon", "Sprint 40 Lines", "Ultra", "Endless", "Practice"]
const MODE_BLURBS := [
	"Clear 150 lines through 15 levels.\nThe stage changes as you climb!",
	"Clear 40 lines as fast as you can.\nEvery hundredth of a second counts.",
	"Score as many points as possible\nin exactly 3 minutes.",
	"No goal, no limit. Levels keep\nrising until the stack wins.",
	"Pick your speed and train calmly.\nNo records, no pressure.",
]

var mode: int = Mode.MARATHON
var start_level := 1
var level_progression := true
var lines_per_level := 10
var max_level := 15
var line_goal := 0
var time_limit := 0.0
var gravity_enabled := true
var save_records := true
var hold_enabled := true
var next_count := 5
var lock_delay := 0.5
var max_lock_resets := 15
var line_clear_delay := 0.32
var entry_delay := 0.0
var soft_drop_factor := 20.0
var rng_seed := -1


static func for_mode(m: int, options: Dictionary = {}) -> GameRules:
	var r := GameRules.new()
	r.mode = m
	r.start_level = clampi(int(options.get("start_level", 1)), 1, 20)
	match m:
		Mode.MARATHON:
			r.line_goal = 150
			r.max_level = 15
			r.start_level = mini(r.start_level, 15)
		Mode.SPRINT:
			r.line_goal = 40
			r.start_level = 1
			r.level_progression = false
		Mode.ULTRA:
			r.time_limit = 180.0
			r.start_level = 1
			r.max_level = 15
		Mode.ENDLESS:
			r.max_level = 99
		Mode.PRACTICE:
			r.save_records = false
			r.max_level = 20
			r.level_progression = bool(options.get("level_up", false))
			r.gravity_enabled = bool(options.get("gravity", true))
	if options.has("hold"):
		r.hold_enabled = bool(options["hold"])
	if options.has("seed"):
		r.rng_seed = int(options["seed"])
	return r


static func mode_id(m: int) -> String:
	return MODE_IDS[m]


static func mode_from_id(id: String) -> int:
	return maxi(MODE_IDS.find(id), 0)


static func mode_name(m: int) -> String:
	return MODE_NAMES[m]
