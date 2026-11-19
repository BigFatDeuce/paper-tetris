extends Node
## Global one-way signal bus. Gameplay publishes what happens; decorative
## systems (Shy Guys, stage effects, camera) listen. Nothing that listens
## here may ever call back into the Tetris engine.

## kind: lines, tetris, tspin, combo, perfect, level_up, hard_drop, lock,
## danger, game_start, game_over, game_clear, pause, resume, stage, hold,
## menu_move, menu_select, menu_back, new_record
signal game_event(kind: StringName, data: Dictionary)


func emit_event(kind: StringName, data: Dictionary = {}) -> void:
	game_event.emit(kind, data)
