class_name LowHealthDamageEffect
extends Passive
## The unit deals extra damage to enemies below a share of their max health.

@export var bonus: float = 0.25
@export_range(0.0, 1.0, 0.05) var threshold: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Finisher.new(self))


class Finisher extends Status:
	var effect: LowHealthDamageEffect

	func _init(p_effect: LowHealthDamageEffect) -> void:
		effect = p_effect

	func modify_damage_dealt(_unit: BattleUnit, target: BattleUnit, amount: float) -> float:
		if target.health < target.max_health * effect.threshold:
			KeepsakeVfx.pop_icon(target, "💀", "vfx_skull")
			return amount * (1.0 + effect.bonus)
		return amount
