class_name RampingBurnStatus
extends Status
## Starlight burning on a unit: deals `total` damage over `duration` seconds, slowly at
## first and faster toward the end. Each hit adds its own, so they stack. The hit it came
## from already went through wards, so the burn skips them.

var source_id: int   # who the damage meter credits
var total: float
var duration: float
var _elapsed: float = 0.0


func _init(p_source_id: int, p_total: float, p_duration: float) -> void:
	source_id = p_source_id
	total = p_total
	duration = maxf(p_duration, 0.01)


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		return
	var before := _elapsed
	_elapsed = minf(_elapsed + delta, duration)
	# Damage dealt so far grows with the square of the time passed, so the rate keeps
	# climbing: a quarter of the total lands in the first half, three quarters in the second.
	var amount := total * (_elapsed * _elapsed - before * before) / (duration * duration)
	var dealt := unit.take_warded_damage(amount)
	unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
	if _elapsed >= duration:
		unit.remove_status(self)
