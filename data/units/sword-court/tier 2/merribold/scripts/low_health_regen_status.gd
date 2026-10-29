class_name LowHealthRegenStatus
extends Status
## Adds health regen that grows as the unit's health drops.

var max_bonus: float   # extra regen per second at (near) zero health


func _init(p_max_bonus: float) -> void:
	max_bonus = p_max_bonus


## The bonus scales linearly with missing health: none at full, max_bonus at zero.
func modify_health_regen(unit: BattleUnit, regen: float) -> float:
	var missing := 1.0 - clampf(unit.health / unit.max_health, 0.0, 1.0)
	return regen + max_bonus * missing
