class_name ShieldedStatEffect
extends Passive
## Spellshield's Insight Empower: while the unit has a shield, Stat is Amount higher.

@export var stat: Stats.Stat = Stats.Stat.INSIGHT
@export var amount: float = 30.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Shielded.new(self))


class Shielded extends Status:
	var effect: ShieldedStatEffect

	func _init(p_effect: ShieldedStatEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == effect.stat and unit.get_shield() > 0.0:
			return value + effect.amount
		return value
