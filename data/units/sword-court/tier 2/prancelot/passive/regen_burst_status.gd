class_name RegenBurstStatus
extends Status
## A burst of extra healing over time, credited to whoever gave it. Several stack.

var source_id: int
var per_second: float
var time_left: float


func _init(p_source_id: int, p_per_second: float, p_duration: float) -> void:
	source_id = p_source_id
	per_second = p_per_second
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	if unit.active:
		unit.heal(per_second * minf(delta, time_left), source_id)
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
