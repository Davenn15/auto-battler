class_name ChargeDenialEffect
extends Passive
## Enemies gain less charge for landing attacks on the unit.

@export_range(0.0, 1.0, 0.05) var reduction: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Deny.new(reduction))


class Deny extends Status:
	var reduction: float

	func _init(p_reduction: float) -> void:
		reduction = p_reduction

	func modify_attacker_charge(_unit: BattleUnit, _attacker: BattleUnit, amount: float) -> float:
		return amount * (1.0 - reduction)
