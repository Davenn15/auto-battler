class_name DamageCapStatus
extends Status

var max_share: float


func _init(p_max_share: float) -> void:
	max_share = p_max_share


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	return minf(damage, unit.max_health * max_share)
