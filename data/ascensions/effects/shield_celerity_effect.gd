class_name ShieldCelerityEffect
extends Passive
## An Ascension effect (Sword Court, Gilded Stride): each time a unit gains a Shield, it
## gains Celerity for the rest of combat (a permanent gain), at most once every Cooldown
## seconds.

@export var celerity: float = 5.0
@export var cooldown: float = 1.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldCelerityStatus.new(self))


class ShieldCelerityStatus extends Status:
	var effect: ShieldCelerityEffect
	var _wait := 0.0

	func _init(p_effect: ShieldCelerityEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(_unit: BattleUnit, delta: float) -> void:
		_wait = maxf(_wait - delta, 0.0)

	func on_shield_gained(unit: BattleUnit, _amount: float) -> void:
		if _wait > 0.0 or not unit.alive:
			return
		_wait = effect.cooldown
		unit.add_status(PermanentStatStatus.new(Stats.Stat.CELERITY, effect.celerity))
