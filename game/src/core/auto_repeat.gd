class_name AutoRepeat
extends RefCounted
## Delayed Auto Shift / Auto Repeat Rate for lateral movement.
## The most recently pressed direction wins; releasing it falls back to the
## other one if it is still held. The charge is kept across pieces.

const INSTANT := 99

var das := 0.167
var arr := 0.033

var _held := {-1: false, 1: false}
var _dir := 0
var _timer := 0.0
var _charged := false
var _arr_acc := 0.0


func reset() -> void:
	_held = {-1: false, 1: false}
	_dir = 0
	_timer = 0.0
	_charged = false
	_arr_acc = 0.0


## Returns the number of immediate moves (always 1 on a fresh press).
func press(dir: int) -> int:
	_held[dir] = true
	_dir = dir
	_timer = 0.0
	_charged = false
	_arr_acc = 0.0
	return 1


func release(dir: int) -> void:
	_held[dir] = false
	if _dir == dir:
		if _held[-dir]:
			_dir = -dir
			_timer = 0.0
			_charged = false
			_arr_acc = 0.0
		else:
			_dir = 0


func direction() -> int:
	return _dir


## Advances time; returns how many cells to move in `direction()`.
func update(dt: float) -> int:
	if _dir == 0:
		return 0
	if not _charged:
		_timer += dt
		if _timer < das:
			return 0
		_charged = true
		_arr_acc = _timer - das
		if arr <= 0.0:
			return INSTANT
		var first := 1 + int(_arr_acc / arr)
		_arr_acc = fmod(_arr_acc, arr)
		return first
	if arr <= 0.0:
		return INSTANT
	_arr_acc += dt
	var n := int(_arr_acc / arr)
	_arr_acc -= n * arr
	return n
