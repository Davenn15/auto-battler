class_name LowHealthWardStatus
extends Status
## Adds wards that grow as the unit's health drops.

const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]

var max_bonus: float


func _init(p_max_bonus: float) -> void:
	max_bonus = p_max_bonus


## The bonus scales linearly with missing health: none at full, max_bonus at zero.
func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat not in WARDS:
		return value
	var missing := 1.0 - clampf(unit.health / unit.max_health, 0.0, 1.0)
	return value + max_bonus * missing
