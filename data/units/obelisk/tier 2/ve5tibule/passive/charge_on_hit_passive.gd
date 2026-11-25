class_name ChargeOnHitPassive
extends Passive
## Vestibule's passive: his attacks gain the Hit Effect: he gains Charge.

@export var charge: float = 5.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ChargeOnHitStatus.new(self))


class ChargeOnHitStatus extends Status:
	var passive: ChargeOnHitPassive

	func _init(p_passive: ChargeOnHitPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return ChargeHit.new(unit, passive.charge)


class ChargeHit extends HitEffect:
	var attacker   # untyped: may be freed before the hit lands
	var charge: float

	func _init(p_attacker: BattleUnit, p_charge: float) -> void:
		attacker = p_attacker
		charge = p_charge

	func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if is_instance_valid(attacker) and attacker.alive:
			attacker.gain_charge(charge)
