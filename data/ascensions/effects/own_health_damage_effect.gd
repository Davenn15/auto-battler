class_name OwnHealthDamageEffect
extends Passive
## An Ascension effect (Bone Breaker): the unit's attacks deal bonus damage equal to Share
## of its own max health (added to the attack, so it can Wrack), and each enemy its Gambit
## damages takes that much again as a separate hit of its attack's damage type.

@export_range(0.0, 0.5, 0.005) var share: float = 0.03


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BoneBreakerStatus.new(self))


class BoneBreakerStatus extends Status:
	var effect: OwnHealthDamageEffect

	func _init(p_effect: OwnHealthDamageEffect) -> void:
		effect = p_effect

	func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
		return damage + unit.max_health * effect.share

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not target.alive:
			return
		var dealt := target.take_damage(unit.max_health * effect.share, 0, unit.get_attack_damage_type(), false, unit)
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
