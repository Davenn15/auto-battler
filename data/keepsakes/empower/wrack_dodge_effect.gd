class_name WrackDodgeEffect
extends Passive
## Eel Sash's Wrack Empower: each time the unit Wracks, +Per Wrack dodge chance (up to Max),
## and the Duration resets for all of it.

@export var per_wrack: float = 0.1
@export var max_bonus: float = 0.3
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Slick.new(self))


class Slick extends Status:
	var effect: WrackDodgeEffect
	var _bonus := 0.0
	var _left := 0.0

	func _init(p_effect: WrackDodgeEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_wrack_landed(_unit: BattleUnit, _target) -> void:
		_bonus = minf(_bonus + effect.per_wrack, effect.max_bonus)
		_left = effect.duration

	func tick(_unit: BattleUnit, delta: float) -> void:
		if _left > 0.0:
			_left -= delta
			if _left <= 0.0:
				_bonus = 0.0

	func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
		return chance + _bonus
