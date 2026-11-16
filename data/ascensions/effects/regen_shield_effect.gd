class_name RegenShieldEffect
extends Passive
## An Ascension effect (Renewal, for Gallavost): the unit gains Regen health regen, and while it has
## a shield, its health regen restores that shield too (at the same rate), up to the
## shield it started combat with (Gallavost's passive), or Fallback Cap of its max health.
## It only tops up a shield the unit still has: it never makes a new one.

@export var regen: float = 25.0
@export_range(0.0, 2.0, 0.05) var fallback_cap: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RegenShieldStatus.new(self))


class RegenShieldStatus extends Status:
	var effect: RegenShieldEffect

	func _init(p_effect: RegenShieldEffect) -> void:
		effect = p_effect

	func modify_health_regen(_unit: BattleUnit, value: float) -> float:
		return value + effect.regen

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		var current := unit.get_shield()
		if current <= 0.0:
			return   # no shield to restore
		var cap := unit.max_health * effect.fallback_cap
		for status in unit.statuses:
			if status is PurityStatus and status.starting_shield > 0.0:
				cap = status.starting_shield
		var amount := minf(unit.get_health_regen() * delta, cap - current)
		for status in unit.statuses:
			amount = status.modify_shield_received(unit, amount)   # e.g. halved in overtime
		if amount <= 0.0:
			return
		# Top up the longest-lasting shield (her lasting starting shield, if she has it).
		var best: ShieldStatus = null
		for status in unit.statuses:
			if status is ShieldStatus and status.shield > 0.0 and (best == null or status.time_left > best.time_left):
				best = status
		if best == null:
			return
		best.shield += amount
		unit.get_tree().call_group("damage_tracker", "record_shielding", unit.get_instance_id(), amount)
