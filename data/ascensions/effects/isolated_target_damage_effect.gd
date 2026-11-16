class_name IsolatedTargetDamageEffect
extends Passive
## An Ascension effect (Break Formation): all damage the unit deals to an enemy with no
## allies in the cells next to it is increased by Bonus.

@export_range(0.0, 2.0, 0.01) var bonus: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(IsolatedBonusStatus.new(bonus))


class IsolatedBonusStatus extends Status:
	var bonus: float

	func _init(p_bonus: float) -> void:
		bonus = p_bonus

	func modify_damage_against(_unit: BattleUnit, target: BattleUnit, amount: float) -> float:
		if target.alive and not LoneStartStatEffect.has_adjacent_ally(target):
			return amount * (1.0 + bonus)
		return amount
