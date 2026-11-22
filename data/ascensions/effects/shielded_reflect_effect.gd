class_name ShieldedReflectEffect
extends Passive
## An Ascension effect: while the unit has a Shield, each projectile that reaches it has an
## extra Chance to be sent back at its shooter (on top of any other reflect it has, such as
## Wesper's parry or Balmede's plant).

@export_range(0.0, 1.0, 0.05) var chance: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldReflectStatus.new(self))


class ShieldReflectStatus extends Status:
	const COLOR := Color(0.75, 0.85, 1.0)   # shield blue
	var effect: ShieldedReflectEffect

	func _init(p_effect: ShieldedReflectEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
		if unit.get_shield() <= 0.0 or CombatRng.randf() >= effect.chance:
			return false
		if not projectile.reflect(unit, unit.get_stat(Stats.Stat.WRACK_CHANCE)):
			return false
		unit.show_float_text("Reflect", COLOR)
		return true
