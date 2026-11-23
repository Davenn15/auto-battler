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
			CurrentMark.feed(target)

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


## Shared Current's marker: a faint green cylinder around whoever is getting the army's
## Regeneration right now. Every pooling unit feeds it each frame; once nobody does (the
## unit is full, or someone else is lower), it fades out and goes away.
class CurrentMark extends Node2D:
	const NAME := &"SharedCurrentMark"
	const COLOR := Color(0.45, 1.0, 0.55)
	const HOLD := 0.15   # seconds it stays after its last feed
	const FADE_SPEED := 4.0
	var radius := 24.0
	var height := 60.0
	var _fed := 0.0
	var _alpha := 0.0
	var _time := 0.0

	## Shows (or keeps) the marker on `unit`.
	static func feed(unit: BattleUnit) -> void:
		if not KeepsakeVfx.enabled():
			return
		var mark := unit.get_node_or_null(NodePath(NAME)) as CurrentMark
		if mark == null:
			mark = CurrentMark.new()
			mark.name = NAME
			var size := KeepsakeVfx._sprite_size(unit)
			mark.radius = maxf(size.x * 0.5, 18.0)
			mark.height = maxf(size.y, 40.0) + 8.0
			mark.z_index = 11
			unit.add_child(mark)
		mark._fed = HOLD

	func _process(delta: float) -> void:
		_time += delta
		_fed -= delta
		var want := 1.0 if _fed > 0.0 else 0.0
		_alpha = move_toward(_alpha, want, delta * FADE_SPEED)
		var owner_unit := get_parent() as BattleUnit
		if (_alpha <= 0.0 and want == 0.0) or owner_unit == null or not owner_unit.alive:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var squash := 0.32   # the ellipses' height / width
		var bottom := height * 0.5
		var top := -height * 0.5
		var a := _alpha * (0.85 + 0.15 * sin(_time * 4.0))
		# The walls: a see-through band, brighter toward the edges like a glass tube.
		var bands := 10
		for i in bands:
			var x0 := lerpf(-radius, radius, float(i) / bands)
			var x1 := lerpf(-radius, radius, float(i + 1) / bands)
			var edge := absf((x0 + x1) / 2.0) / radius
			var shade := 0.05 + 0.13 * edge * edge
			var y_off0 := sqrt(maxf(0.0, 1.0 - pow(x0 / radius, 2))) * radius * squash
			var y_off1 := sqrt(maxf(0.0, 1.0 - pow(x1 / radius, 2))) * radius * squash
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, top + y_off0), Vector2(x1, top + y_off1),
				Vector2(x1, bottom + y_off1), Vector2(x0, bottom + y_off0)]),
				Color(COLOR, shade * a))
		# Rims: the base ring stronger, the top ring fainter, and the two side lines.
		draw_set_transform(Vector2(0, bottom), 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(COLOR, 0.55 * a), 2.0 / squash * 0.5)
		draw_set_transform(Vector2(0, top), 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(COLOR, 0.3 * a), 1.0 / squash * 0.5)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(-radius, top), Vector2(-radius, bottom), Color(COLOR, 0.35 * a), 1.0)
		draw_line(Vector2(radius, top), Vector2(radius, bottom), Color(COLOR, 0.35 * a), 1.0)
		# A few motes drifting up inside it.
		for i in 6:
			var y := bottom - fmod(_time * 22.0 + i * height / 6.0, height)
			var x := sin(i * 2.1 + _time * 1.7) * radius * 0.7
			draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), Color(0.8, 1.0, 0.85, 0.5 * a))
