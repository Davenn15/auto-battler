class_name ChargeDenialEffect
extends Passive
## Nullstone: enemies gain Reduction less charge for landing attacks on the unit, and the
## unit gains Self Bonus more charge from being hit.

@export_range(0.0, 1.0, 0.05) var reduction: float = 0.3
@export var self_bonus: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Deny.new(reduction, self_bonus))


class Deny extends Status:
	var reduction: float
	var self_bonus: float

	func _init(p_reduction: float, p_self_bonus: float = 0.0) -> void:
		reduction = p_reduction
		self_bonus = p_self_bonus

	func modify_attacker_charge(_unit: BattleUnit, _attacker: BattleUnit, amount: float) -> float:
		return amount * (1.0 - reduction)

	func modify_hit_charge(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 + self_bonus)
