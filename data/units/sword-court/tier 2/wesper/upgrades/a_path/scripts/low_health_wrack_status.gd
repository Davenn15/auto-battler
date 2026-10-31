class_name LowHealthWrackStatus
extends Status

var bonus: float
var threshold: float


func _init(p_bonus: float, p_threshold: float) -> void:
	bonus = p_bonus
	threshold = p_threshold


func modify_wrack_chance(_unit: BattleUnit, target: BattleUnit, chance: float) -> float:
	if target.health <= target.max_health * threshold:
		return chance + bonus
	return chance
