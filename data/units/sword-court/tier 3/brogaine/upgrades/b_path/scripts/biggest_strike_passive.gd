class_name BiggestStrikePassive
extends Passive
## Brogaine B1: his attacks against the enemy with the most max health gain Hit Effect:
## deal Share of its max health as bonus Might damage.

@export_range(0.0, 0.5, 0.005) var share: float = 0.03


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BiggestStrikeStatus.new(self))


class BiggestStrikeStatus extends Status:
	var passive: BiggestStrikePassive

	func _init(p_passive: BiggestStrikePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		if not unit._is_valid_target(unit.target) or unit.target != RowdyGambit.biggest_enemy(unit):
			return null
		return BiggestHit.new(unit, passive.share)


## Settled as the attack is made: the bonus lands even if Brogaine has died meanwhile.
class BiggestHit extends HitEffect:
	var attacker   # untyped: may be freed
	var attacker_id: int
	var share: float

	func _init(p_attacker: BattleUnit, p_share: float) -> void:
		attacker = p_attacker
		attacker_id = p_attacker.get_instance_id()
		share = p_share

	func apply(target: BattleUnit, dealt: float, wrack_level: int) -> void:
		if not target.alive or dealt <= 0.0:
			return   # dodged, or already dead
		var by: BattleUnit = attacker if is_instance_valid(attacker) else null
		var amount := target.max_health * share
		var hit := target.take_damage(amount, wrack_level, Stats.DamageType.MIGHT, false, by)
		target.get_tree().call_group("damage_tracker", "record_damage", attacker_id, hit)
