class_name BagRandomizer
extends RefCounted
## Classic "7-bag" generator: every bag of seven contains each piece once.

var _rng := RandomNumberGenerator.new()
var _bag: Array[int] = []


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func next_piece() -> int:
	if _bag.is_empty():
		_refill()
	return _bag.pop_back()


func _refill() -> void:
	_bag = Tetromino.TYPES.duplicate()
	# Fisher-Yates with our own RNG (deterministic with a seed)
	for i in range(_bag.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = t
