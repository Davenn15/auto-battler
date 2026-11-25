class_name HealOnHitEffect
extends Passive
## Crusher's Health Empower: each attack that lands heals the unit for Share of its max
## health.

@export var share: float = 0.01


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Mend.new(self))


class Mend extends Status:
	var effect: HealOnHitEffect

	func _init(p_effect: HealOnHitEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_attack_hit(unit: BattleUnit, _target: BattleUnit, dealt: float) -> void:
		if dealt > 0.0:
			unit.heal(unit.max_health * effect.share, unit.get_instance_id())
