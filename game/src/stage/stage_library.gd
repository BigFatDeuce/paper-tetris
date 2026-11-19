class_name StageLibrary
extends RefCounted
## Every diorama stage: its art folder, music, ambience and who lives there.
## Add a stage: render its layers into assets/stages/<id>/ and add an entry.

const ORDER := ["toybox", "meadow", "flowers", "desert", "jungle", "volcano", "snow", "stars", "bowser"]

const STAGES := {
	"toybox": {
		"name": "Shy Guy's Toy Box", "music": "stage_toybox",
		"ambient": "confetti", "tint": Color(1, 1, 1),
		"crowd": ["shyguy_red", "shyguy_blue", "shyguy_green", "shyguy_pink", "shyguy_yellow"],
		"specials": ["groove_guy", "traffic_guy", "sky_guy"],
		"rare": ["anti_guy", "general_guy", "stilt_guy"],
	},
	"meadow": {
		"name": "Pleasant Path", "music": "stage_meadow",
		"ambient": "leaves", "tint": Color(1, 1, 1),
		"crowd": ["shyguy_red", "shyguy_green", "shyguy_yellow", "shyguy_blue"],
		"specials": ["sky_guy", "spy_guy"],
		"rare": ["anti_guy", "stilt_guy"],
	},
	"flowers": {
		"name": "Flower Fields", "music": "stage_flowers",
		"ambient": "petals", "tint": Color(1, 1, 1),
		"crowd": ["shyguy_pink", "shyguy_yellow", "shyguy_red", "shyguy_blue"],
		"specials": ["sky_guy", "groove_guy"],
		"rare": ["anti_guy", "spy_guy"],
	},
	"desert": {
		"name": "Dry Dry Desert", "music": "stage_desert",
		"ambient": "sand", "tint": Color(1, 0.98, 0.94),
		"crowd": ["shyguy_yellow", "shyguy_red", "shyguy_blue"],
		"specials": ["stilt_guy", "sky_guy"],
		"rare": ["anti_guy", "general_guy"],
	},
	"jungle": {
		"name": "Jade Jungle", "music": "stage_jungle",
		"ambient": "fireflies", "tint": Color(1, 1, 1),
		"crowd": ["spear_guy", "spear_guy", "shyguy_green", "shyguy_red"],
		"specials": ["spy_guy", "groove_guy"],
		"rare": ["anti_guy", "sky_guy"],
	},
	"volcano": {
		"name": "Mt. Lavalava", "music": "stage_volcano",
		"ambient": "embers", "tint": Color(1, 0.95, 0.9),
		"crowd": ["pyro_guy", "pyro_guy", "shyguy_red", "pyro_guy"],
		"specials": ["spear_guy", "groove_guy"],
		"rare": ["anti_guy", "general_guy"],
	},
	"snow": {
		"name": "Shiver Mountain", "music": "stage_snow",
		"ambient": "snow", "tint": Color(0.97, 0.98, 1.0),
		"crowd": ["shyguy_blue", "shyguy_pink", "shyguy_red", "shyguy_green"],
		"specials": ["sky_guy", "stilt_guy"],
		"rare": ["anti_guy", "general_guy"],
	},
	"stars": {
		"name": "Shooting Star Summit", "music": "stage_stars",
		"ambient": "stars", "tint": Color(0.95, 0.95, 1.0),
		"crowd": ["shyguy_blue", "shyguy_yellow", "shyguy_pink", "shyguy_red", "shyguy_green"],
		"specials": ["sky_guy", "groove_guy", "general_guy"],
		"rare": ["anti_guy", "stilt_guy", "spy_guy"],
	},
	"bowser": {
		"name": "Bowser's Castle", "music": "stage_bowser",
		"ambient": "embers", "tint": Color(1, 0.94, 0.92),
		"crowd": ["shyguy_red", "pyro_guy", "shyguy_blue", "shyguy_green"],
		"specials": ["spy_guy", "spear_guy", "groove_guy"],
		"rare": ["anti_guy", "general_guy"],
		# the master of the castle watches from the back (src/stage/bowser.gd)
		"boss": {"pos": Vector2(1715, 790)},
	},
}


static func ids() -> Array:
	return ORDER


static func get_stage(id: String) -> Dictionary:
	return STAGES.get(id, STAGES["toybox"])


static func stage_name(id: String) -> String:
	return get_stage(id)["name"]


## Marathon / Endless journey: two levels per stage, then loop.
static func for_level(level: int) -> String:
	var idx := clampi((level - 1) / 2, 0, 9999) % ORDER.size()
	return ORDER[idx]


## Default stage for a mode when the player picks "auto".
static func default_for_mode(mode: int) -> String:
	match mode:
		GameRules.Mode.SPRINT: return "desert"
		GameRules.Mode.ULTRA: return "flowers"
		GameRules.Mode.PRACTICE: return "meadow"
	return "toybox"


static func folder(id: String) -> String:
	return "res://assets/stages/%s/" % id
