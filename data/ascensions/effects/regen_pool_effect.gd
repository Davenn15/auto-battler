class_name RegenPoolEffect
extends Passive
## An Ascension effect (Obelisk "Shared Current"): the unit gains Regen Bonus Regeneration,
## and all Regeneration in its army goes to whichever ally has the lowest health % right
## now (ties: the lower instance id) instead of healing the unit that has it. When nobody
## is hurt, every unit keeps its own. Summons and other allies without the Ascension take
## part too: they're given the pooling (without the bonus) as soon as they appear.

@export var regen_bonus: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	PoolStatus.give(unit, regen_bonus)


class PoolStatus extends Status:
	var bonus: float
	var _measuring := false   # true while reading the unit's own Regeneration

	## Gives `unit` the pooling (or raises its bonus, if it already has it).
	static func give(unit: BattleUnit, p_bonus: float) -> void:
		for status in unit.statuses:
			if status is PoolStatus:
				status.bonus = maxf(status.bonus, p_bonus)
				return
		var pool := PoolStatus.new()
		pool.bonus = p_bonus
		unit.add_status(pool)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_health_regen(_unit: BattleUnit, value: float) -> float:
		return value + bonus

	## While someone in the army is hurt, the unit doesn't regenerate itself: it sends its
	## Regeneration to the most hurt ally instead (tick). Reading its own value (in tick)
	## goes around this.
	func modify_final_health_regen(unit: BattleUnit, value: float) -> float:
		if _measuring:
			return value
		return 0.0 if PoolStatus.most_hurt(unit) != null else value

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		# Every ally takes part: give the pooling to any that don't have it yet (summons).
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally != null and ally != unit and ally.alive and ally.team == unit.team and PoolStatus.of(ally) == null:
				PoolStatus.give(ally, 0.0)
		var target := PoolStatus.most_hurt(unit)
		if target == null:
			return   # nobody hurt: it regenerates itself as normal
		_measuring = true
		var regen := unit.get_health_regen()
		_measuring = false
		if regen > 0.0:
			target.heal(regen * delta, unit.get_instance_id(), false)

	## The living, fighting ally of `unit` (itself included) with the lowest health % below
	## full; ties go to the lower instance id. Null if nobody is hurt.
	static func most_hurt(unit: BattleUnit) -> BattleUnit:
		var best: BattleUnit = null
		var best_share := 1.0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or not ally.alive or not ally.active or ally.team != unit.team or ally.max_health <= 0.0:
				continue
			var share := ally.health / ally.max_health
			if share >= 1.0:
				continue
			if best == null or share < best_share - 0.000001 \
					or (absf(share - best_share) <= 0.000001 and ally.get_instance_id() < best.get_instance_id()):
				best = ally
				best_share = share
		return best

	static func of(unit: BattleUnit) -> PoolStatus:
		for status in unit.statuses:
			if status is PoolStatus:
				return status
		return null
