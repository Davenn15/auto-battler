class_name LowHealthFuryStatus
extends Status
## The lower the unit's health, the higher its `stats` (its attributes, or its Wards):
## nothing at full health, rising evenly to `max_bonus` each as health nears zero.

const ATTRIBUTES := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]
const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]

var max_bonus: float
var stats: Array


func _init(p_max_bonus: float, p_stats: Array = ATTRIBUTES) -> void:
	max_bonus = p_max_bonus
	stats = p_stats


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat not in stats or unit.max_health <= 0.0:
		return value
	var missing := 1.0 - clampf(unit.health / unit.max_health, 0.0, 1.0)
	return value + max_bonus * missing
