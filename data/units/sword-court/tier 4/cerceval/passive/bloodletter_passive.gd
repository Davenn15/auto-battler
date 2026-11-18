class_name BloodletterPassive
extends Passive
## Cerceval: his attack and Gambit damage also inflict Bleed for Bleed Share of the damage
## dealt (see Bleed), and he heals for Heal Share of all Bleed damage enemies within his
## attack range take (anyone's Bleed).

@export_range(0.0, 2.0, 0.05) var bleed_share: float = 0.3
@export_range(0.0, 2.0, 0.05) var heal_share: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BloodletterStatus.new(self))


class BloodletterStatus extends Status:
	var passive: BloodletterPassive

	func _init(p_passive: BloodletterPassive) -> void:
		passive = p_passive

	func on_attack_hit(unit: BattleUnit, enemy: BattleUnit, dealt: float) -> void:
		Bleed.apply(enemy, dealt * passive.bleed_share, unit, false)

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		Bleed.apply(target, amount * passive.bleed_share, unit, false)

	func on_enemy_bleed(unit: BattleUnit, victim: BattleUnit, dealt: float) -> void:
		if unit.active and unit.grid.get_distance(unit.cell, victim.cell) <= unit.attack_range:
			unit.heal(dealt * passive.heal_share, unit.get_instance_id())
			CercevalFx.blood_trail(victim, unit)
