class_name ReflectChancePassive
extends Passive
## Lordred B2: each projectile that reaches him has Chance to be sent back at its shooter.

@export_range(0.0, 1.0, 0.05) var chance: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ReflectChanceStatus.new(self))


class ReflectChanceStatus extends Status:
	const COLOR := Color(0.85, 0.15, 0.15)   # Lordred's taunt red
	var passive: ReflectChancePassive

	func _init(p_passive: ReflectChancePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
		if CombatRng.randf() >= passive.chance:
			return false
		if not projectile.reflect(unit, unit.get_stat(Stats.Stat.WRACK_CHANCE)):
			return false
		unit.show_float_text("Reflect", COLOR)
		return true
