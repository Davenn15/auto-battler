class_name StatOnWrackEffect
extends Passive
## Exploding Top's Insight Empower: whenever the unit Wracks (attacks, Gambit damage or
## effects), Stat is Amount higher for Duration seconds. Wracking again refreshes it.

@export var stat: Stats.Stat = Stats.Stat.INSIGHT
@export var amount: float = 20.0
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Surge.new(self))


class Surge extends Status:
	var effect: StatOnWrackEffect
	var _left := 0.0

	func _init(p_effect: StatOnWrackEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_wrack_landed(_unit: BattleUnit, _target) -> void:
		_left = effect.duration

	func tick(_unit: BattleUnit, delta: float) -> void:
		_left = maxf(_left - delta, 0.0)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + effect.amount if stat == effect.stat and _left > 0.0 else value
