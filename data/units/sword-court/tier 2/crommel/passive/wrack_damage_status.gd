class_name WrackDamageStatus
extends Status
## Adds to the unit's wrack damage stat.

var bonus: float   # added to wrack damage (0.25 = wracks deal 25% more extra damage)


func _init(p_bonus: float) -> void:
	bonus = p_bonus


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.WRACK_DAMAGE:
		return value + bonus
	return value
