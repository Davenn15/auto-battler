class_name ChargeHitEffect
extends HitEffect
## Gives a unit charge when the attack lands. A dodged attack gives none.

var unit_id: int
var amount: float


func _init(p_unit_id: int, p_amount: float) -> void:
	unit_id = p_unit_id
	amount = p_amount


func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	var unit := instance_from_id(unit_id) as BattleUnit
	if unit != null:
		unit.gain_charge(amount)
