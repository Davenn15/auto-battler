class_name UnshieldedChargeStatus
extends Status
## While the unit has no shield, it gains charge over time.

var per_second: float


func _init(p_per_second: float) -> void:
	per_second = p_per_second


func tick(unit: BattleUnit, delta: float) -> void:
	if unit.active and unit.get_shield() <= 0.0:
		unit.gain_charge(per_second * delta)
