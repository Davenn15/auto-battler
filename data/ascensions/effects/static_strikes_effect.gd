class_name StaticStrikesEffect
extends Passive
## An Ascension effect (Obelisk, Static Strikes): a unit's attacks gain the Hit Effect: it
## gains Voltage. An attack that gives only part of the usual Charge (one of Shred's three
## edges) gives that part of the Voltage.

@export var voltage: float = 1.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StaticStatus.new(self))


class StaticStatus extends Status:
	var effect: StaticStrikesEffect

	func _init(p_effect: StaticStrikesEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		var share := 1.0
		for status in unit.statuses:
			if status != self:
				share = status.modify_own_attack_charge(unit, share)
		return VoltHit.new(unit, effect.voltage * clampf(share, 0.0, 1.0))


class VoltHit extends HitEffect:
	var attacker   # untyped: may be freed before the hit lands
	var amount: float

	func _init(p_attacker: BattleUnit, p_amount: float) -> void:
		attacker = p_attacker
		amount = p_amount

	func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if is_instance_valid(attacker) and attacker.alive and amount > 0.0:
			VoltageStatus.ensure(attacker).add(amount)
