extends Node
## Languages. The game is written in English; French comes from
## data/lang/fr.json (English text -> French text) registered with the
## TranslationServer, so every Label translates itself and switches live.
## Formatted strings go through tr() / Lang.t() before formatting.

const LANGS := ["en", "fr"]
const NAMES := {"en": "English", "fr": "Français"}
const FILES := {"fr": "res://data/lang/fr.json"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for code: String in FILES:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILES[code]))
		if typeof(d) != TYPE_DICTIONARY:
			push_error("unreadable translation %s" % FILES[code])
			continue
		var t := Translation.new()
		t.locale = code
		for k: String in d:
			if not k.begins_with("//"):
				t.add_message(k, str(d[k]))
		TranslationServer.add_translation(t)
	apply()
	Settings.changed.connect(func(k: String):
		if k == "language":
			apply())


## The language in use ("auto" follows the system: French if it is French).
func current() -> String:
	var l := str(Settings.get_value("language"))
	if not l in LANGS:
		l = "fr" if OS.get_locale_language() == "fr" else "en"
	return l


func apply() -> void:
	TranslationServer.set_locale(current())


func cycle(dir: int) -> void:
	var i := LANGS.find(current())
	Settings.set_value("language", LANGS[posmod(i + dir, LANGS.size())])


static func t(s: String) -> String:
	return String(TranslationServer.translate(s))
