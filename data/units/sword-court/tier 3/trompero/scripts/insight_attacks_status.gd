class_name InsightAttacksStatus
extends Status
## Turns the unit's basic attacks into Insight damage and adds bonus damage from Insight.

var insight_scaling: float


func _init(p_insight_scaling: float) -> void:
	insight_scaling = p_insight_scaling


func modify_attack_damage_type(_unit: BattleUnit, _damage_type: int) -> int:
	return Stats.DamageType.INSIGHT


func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
	return Stats.scaled(damage, insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))
