class_name GambitShieldEffect
extends Passive
## Each time the unit plays its Gambit, it gains a shield sized from its max charge.

## Shield = this x max charge (2 = twice max charge).
@export var charge_multiplier: float = 2.0
@export var duration: float = 5.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Watcher.new(self))


class Watcher extends Status:
	var effect: GambitShieldEffect

	func _init(p_effect: GambitShieldEffect) -> void:
		effect = p_effect

	func on_gambit(unit: BattleUnit) -> void:
		unit.add_shield(unit.max_charge * effect.charge_multiplier, effect.duration, unit.get_instance_id())
