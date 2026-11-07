class_name KeepsakeStatsStatus
extends Status
## Adds one equipped keepsake's stats to the unit for the battle.

var keepsake: Keepsake


func _init(p_keepsake: Keepsake) -> void:
	keepsake = p_keepsake


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	return value + keepsake.get_stat_bonuses().get(stat, 0.0)
