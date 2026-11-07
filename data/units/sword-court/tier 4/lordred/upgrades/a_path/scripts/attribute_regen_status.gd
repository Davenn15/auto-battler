class_name AttributeRegenStatus
extends Status
## Adds health regen equal to a share of the unit's Might + Insight + Celerity.

var scaling: float   # regen per second per attribute point


func _init(p_scaling: float) -> void:
	scaling = p_scaling


func modify_health_regen(unit: BattleUnit, regen: float) -> float:
	var total := unit.get_stat(Stats.Stat.MIGHT) + unit.get_stat(Stats.Stat.INSIGHT) \
			+ unit.get_stat(Stats.Stat.CELERITY)
	return regen + total * scaling
