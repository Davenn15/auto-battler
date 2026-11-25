class_name SupportBoostEffect
extends Passive
## Saviour's Health Empower: every heal and shield the unit gives is Bonus bigger.

@export var bonus: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Boost.new(self))


class Boost extends Status:
	var effect: SupportBoostEffect

	func _init(p_effect: SupportBoostEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_outgoing_support(_unit: BattleUnit, _target: BattleUnit, amount: float, _is_shield: bool, _from_gambit: bool) -> float:
		return amount * (1.0 + effect.bonus)
