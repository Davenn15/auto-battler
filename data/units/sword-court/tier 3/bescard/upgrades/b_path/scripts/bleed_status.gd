class_name BleedStatus
extends Status
## Deals damage over time that skips wards. Each one is separate, so bleeds stack.

var source_id: int        # who the damage meter credits
var damage_per_second: float
var time_left: float


func _init(p_source_id: int, p_damage_per_second: float, p_duration: float) -> void:
	source_id = p_source_id
	damage_per_second = p_damage_per_second
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		return
	var step := minf(delta, time_left)
	time_left -= delta
	var dealt := unit.take_warded_damage(damage_per_second * step)
	unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
	if time_left <= 0.0:
		unit.remove_status(self)
