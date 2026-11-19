extends Node
## Local records and lifetime statistics (user://records.json).

signal records_changed(mode_id: String)

const PATH := "user://records.json"
const MAX_ENTRIES := 10
const VERSION := 1

var data := {}
var path := PATH


func _ready() -> void:
	load_data()


func _empty() -> Dictionary:
	var recs := {}
	for id: String in GameRules.MODE_IDS:
		recs[id] = []
	return {
		"version": VERSION,
		"records": recs,
		"lifetime": {"games": 0, "lines": 0, "tetrises": 0, "pieces": 0, "play_time": 0.0},
	}


func load_data() -> void:
	data = _empty()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("records.json is unreadable, starting fresh")
		return
	var recs: Dictionary = parsed.get("records", {})
	for id: String in GameRules.MODE_IDS:
		if recs.has(id) and typeof(recs[id]) == TYPE_ARRAY:
			var list: Array = []
			for r in recs[id]:
				if typeof(r) == TYPE_DICTIONARY:
					list.append(_ints(r))
			data["records"][id] = list
	var life: Dictionary = parsed.get("lifetime", {})
	for k: String in data["lifetime"].keys():
		if life.has(k):
			data["lifetime"][k] = life[k] if k == "play_time" else int(life[k])


func save() -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("cannot write records")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, path)


func records(mode_id: String) -> Array:
	return data["records"].get(mode_id, [])


func best(mode_id: String) -> Dictionary:
	var r := records(mode_id)
	return r[0] if not r.is_empty() else {}


static func is_better(mode_id: String, a: Dictionary, b: Dictionary) -> bool:
	if mode_id == "sprint":
		return float(a.get("time", 1e9)) < float(b.get("time", 1e9))
	if int(a.get("score", 0)) != int(b.get("score", 0)):
		return int(a.get("score", 0)) > int(b.get("score", 0))
	if int(a.get("lines", 0)) != int(b.get("lines", 0)):
		return int(a.get("lines", 0)) > int(b.get("lines", 0))
	return float(a.get("time", 0)) < float(b.get("time", 0))


## Inserts the entry if it qualifies. Returns its rank (0 = best) or -1.
func submit(mode_id: String, entry: Dictionary) -> int:
	if not data["records"].has(mode_id):
		data["records"][mode_id] = []
	var list: Array = data["records"][mode_id]
	if not entry.has("date"):
		entry["date"] = Time.get_date_string_from_system()
	var rank := list.size()
	for i in list.size():
		if is_better(mode_id, entry, list[i]):
			rank = i
			break
	if rank >= MAX_ENTRIES:
		return -1
	list.insert(rank, entry)
	while list.size() > MAX_ENTRIES:
		list.pop_back()
	save()
	records_changed.emit(mode_id)
	return rank


func add_lifetime(stats: Dictionary) -> void:
	var life: Dictionary = data["lifetime"]
	life["games"] = int(life["games"]) + 1
	life["lines"] = int(life["lines"]) + int(stats.get("lines", 0))
	life["tetrises"] = int(life["tetrises"]) + int(stats.get("tetrises", 0))
	life["pieces"] = int(life["pieces"]) + int(stats.get("pieces", 0))
	life["play_time"] = float(life["play_time"]) + float(stats.get("time", 0.0))
	save()


func clear_all() -> void:
	data = _empty()
	save()
	for id: String in GameRules.MODE_IDS:
		records_changed.emit(id)


## JSON reads every number back as a float: restore the integer fields.
static func _ints(r: Dictionary) -> Dictionary:
	for k in ["level", "lines", "pieces", "score", "start_level", "tetrises"]:
		if r.has(k) and (r[k] is float or r[k] is int):
			r[k] = int(r[k])
	return r
