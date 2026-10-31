class_name ShieldBoostStatus
extends Status

var bonus: float


func _init(p_bonus: float) -> void:
	bonus = p_bonus


func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
	return amount * (1.0 + bonus)
