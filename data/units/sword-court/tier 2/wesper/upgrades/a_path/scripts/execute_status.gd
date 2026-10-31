class_name ExecuteStatus
extends Status

const EXECUTE_COLOR := Color(0.9, 0.2, 0.25)

var threshold: float


func _init(p_threshold: float) -> void:
	threshold = p_threshold


func on_attack_hit(unit: BattleUnit, target: BattleUnit, dealt: float) -> void:
	if dealt <= 0.0 or not target.alive or target.health > target.max_health * threshold:
		return
	# The health it had left still counts as Wesper's damage on the meter.
	unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), target.health)
	target.show_float_text("Executed", EXECUTE_COLOR)
	target.kill()
