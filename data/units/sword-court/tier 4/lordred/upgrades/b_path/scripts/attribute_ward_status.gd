class_name AttributeWardStatus
extends Status
## Each ward gains a share of its matching attribute: Might Ward from Might, and so on.

var scaling: float   # 0.2 = +20 ward per 100 attribute


func _init(p_scaling: float) -> void:
	scaling = p_scaling


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD:
			return value + unit.get_stat(Stats.Stat.MIGHT) * scaling
		Stats.Stat.INSIGHT_WARD:
			return value + unit.get_stat(Stats.Stat.INSIGHT) * scaling
		Stats.Stat.CELERITY_WARD:
			return value + unit.get_stat(Stats.Stat.CELERITY) * scaling
	return value
