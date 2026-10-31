class_name ShieldWardStatus
extends Status
## Adds to the unit's wards while it has a shield. The bonuses go through the stat
## system, so they stack with items and buffs and work with anything that reads wards.

var bonuses: Dictionary   # Stats.Stat -> amount added while shielded


func _init(p_bonuses: Dictionary) -> void:
	bonuses = p_bonuses


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if bonuses.has(stat) and unit.get_shield() > 0.0:
		return value + bonuses[stat]
	return value
