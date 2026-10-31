class_name DodgeBuildStatus
extends Status

var per_hit: float
var max_bonus: float
var bonus: float = 0.0


func _init(p_per_hit: float, p_max_bonus: float) -> void:
	per_hit = p_per_hit
	max_bonus = p_max_bonus


## Doesn't change the damage; just counts that a hit landed.
func modify_incoming_damage(_unit: BattleUnit, damage: float) -> float:
	if damage > 0.0:
		bonus = minf(bonus + per_hit, max_bonus)
	return damage


func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
	return chance + bonus


func on_dodge(_unit: BattleUnit) -> void:
	bonus = 0.0
