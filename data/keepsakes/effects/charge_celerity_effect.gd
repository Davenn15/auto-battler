class_name ChargeCelerityEffect
extends Passive
## Extra Celerity for every so much charge the unit is holding.

@export var celerity_per_step: float = 3.0
@export var charge_per_step: float = 10.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Charged.new(self))


class Charged extends Status:
	var effect: ChargeCelerityEffect

	func _init(p_effect: ChargeCelerityEffect) -> void:
		effect = p_effect

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat != Stats.Stat.CELERITY or effect.charge_per_step <= 0.0:
			return value
		return value + floorf(unit.charge / effect.charge_per_step) * effect.celerity_per_step
