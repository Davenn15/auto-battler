class_name LowHealthFuryStatus
extends Status
## The lower the unit's health, the more Might, Insight, and Celerity it has: nothing at
## full health, rising evenly to `max_bonus` each as health nears zero.

var max_bonus: float


func _init(p_max_bonus: float) -> void:
	max_bonus = p_max_bonus


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY:
			if unit.max_health <= 0.0:
				return value
			var missing := 1.0 - clampf(unit.health / unit.max_health, 0.0, 1.0)
			return value + max_bonus * missing
	return value
