class_name InceptiveStatus
extends Status
## Extra wrack chance and wrack damage against enemies above a share of their health.

var bonus_chance: float
var bonus_damage: float
var threshold: float   # 0.5 = above half health


func _init(p_bonus_chance: float, p_bonus_damage: float, p_threshold: float) -> void:
	bonus_chance = p_bonus_chance
	bonus_damage = p_bonus_damage
	threshold = p_threshold


func _applies(target: BattleUnit) -> bool:
	return target != null and target.health > target.max_health * threshold


func modify_wrack_chance(_unit: BattleUnit, target: BattleUnit, chance: float) -> float:
	return chance + bonus_chance if _applies(target) else chance


func modify_wrack_damage(_unit: BattleUnit, target: BattleUnit, value: float) -> float:
	return value + bonus_damage if _applies(target) else value
