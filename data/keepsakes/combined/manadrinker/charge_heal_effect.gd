class_name ChargeHealEffect
extends Passive
## Whenever the unit gains charge, it heals for a multiple of the charge gained.

@export var multiplier: float = 2.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Vigor.new(multiplier))


class Vigor extends Status:
	var multiplier: float

	func _init(p_multiplier: float) -> void:
		multiplier = p_multiplier

	func on_charge_gained(unit: BattleUnit, amount: float) -> void:
		var before := unit.health
		unit.heal(amount * multiplier, unit.get_instance_id())
		if unit.health > before:
			KeepsakeVfx.heal_flash(unit)
