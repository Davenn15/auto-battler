class_name HitShieldEffect
extends Passive
## An Ascension effect (Bulwark Strikes): the unit's attacks gain the Hit Effect: it gains a
## Shield of Share of its max health. Hits top up one Shield (up to Cap of its max health),
## which lasts Duration seconds after the latest hit.

@export_range(0.0, 1.0, 0.01) var share: float = 0.03
@export_range(0.0, 1.0, 0.01) var cap: float = 0.15
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GiverStatus.new(self))


class GiverStatus extends Status:
	var effect: HitShieldEffect

	func _init(p_effect: HitShieldEffect) -> void:
		effect = p_effect

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return ShieldHit.new(unit, effect)


## The Hit Effect: tops up the attacker's Bulwark Shield.
class ShieldHit extends HitEffect:
	var attacker   # untyped: may be freed
	var effect: HitShieldEffect

	func _init(p_attacker: BattleUnit, p_effect: HitShieldEffect) -> void:
		attacker = p_attacker
		effect = p_effect

	func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not is_instance_valid(attacker) or not attacker.alive:
			return
		var amount: float = attacker.max_health * effect.share
		var limit: float = attacker.max_health * effect.cap
		var shield: BulwarkShield = null
		for status in attacker.statuses:
			if status is BulwarkShield:
				shield = status
				break
		if shield == null:
			shield = BulwarkShield.new(0.0, effect.duration)
			attacker.add_status(shield)
		var gained := minf(amount, maxf(limit - shield.shield, 0.0))
		shield.shield += gained
		shield.time_left = effect.duration
		if gained > 0.0:
			attacker.get_tree().call_group("damage_tracker", "record_shielding", attacker.get_instance_id(), gained)


## The Shield those hits keep topping up.
class BulwarkShield extends ShieldStatus:
	pass
