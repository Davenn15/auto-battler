class_name SegCannonGambit
extends Gambit
## SEG.FAULT B: charges its ion cannon (the cast time), then fires one giant ion orb from
## itself through its target, travelling at Orb Speed to the edge of the board. Every enemy
## it passes within Half Width cells of takes Damage (+ Insight Scaling of its Insight) as
## Insight damage, once each.
##   B1 (Mark Duration > 0): enemies it hits are marked for Mark Duration seconds. While
##   marked, Mark Share of the damage any marked enemy takes is also dealt to each other
##   enemy marked by the same orb.
##   B2 (Edge Radius > 0): when the orb reaches the board's edge it detonates, hitting
##   enemies within Edge Radius cells for Edge Share of the damage.
## Its target is its current one, or the nearest enemy if it has none. The orb keeps going
## if SEG.FAULT dies; its damage is fixed when it's fired.

@export var damage: float = 250.0
@export var insight_scaling: float = 1.2
@export var half_width: float = 0.55   # cells either side of the orb's path
@export var orb_speed: float = 250.0   # pixels a second
## B1: 0 = no marks.
@export var mark_duration: float = 0.0
@export_range(0.0, 1.0, 0.05) var mark_share: float = 0.2
## B2: 0 = no detonation at the edge.
@export var edge_radius: float = 0.0
@export_range(0.0, 2.0, 0.05) var edge_share: float = 0.5

static var _last_group := 0   # each orb's marks get their own group number


func can_use(caster: BattleUnit) -> bool:
	return _target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _target(caster)
	if target == null:
		return
	var grid := caster.grid
	var spacing := grid.cell_spacing()
	var from := caster.global_position
	var dir := (target.global_position - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	# Walk out along the line until it leaves the board: that's where the orb stops.
	var edge := from
	var at := from
	for i in 400:
		at += dir * spacing * 0.25
		if not grid.has_cell(grid.world_to_cell(at)):
			break
		edge = at
	var orb := CannonOrb.new()
	orb.gambit = self
	orb.caster = caster
	orb.team = caster.team
	orb.shooter_id = caster.get_instance_id()
	orb.credit_id = caster.get_credit_id()
	orb.is_attack = false
	orb.grants_charge = false
	orb.damage_type = Stats.DamageType.INSIGHT
	orb.polygon = PackedVector2Array()   # drawn as a giant oval, not the plain comet
	orb.grid = grid
	orb.amount = Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	orb.end = edge
	orb.dir = dir
	orb.reach = spacing * half_width
	if mark_duration > 0.0:
		_last_group += 1
		orb.group = _last_group   # this orb's marks share it
	orb.z_index = 13
	caster.get_parent().add_child(orb)
	orb.global_position = from


## One hit of the orb (or its edge detonation) on `unit`. `caster` may be gone by now.
func hit(caster, credit_id: int, unit: BattleUnit, amount: float) -> void:
	if not unit.alive:
		return
	var wrack := 0
	var hit_amount := amount
	if is_instance_valid(caster) and caster is BattleUnit:
		wrack = caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		hit_amount *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := unit.take_damage(BattleUnit.damage_bonus(credit_id, unit, hit_amount), wrack, Stats.DamageType.INSIGHT)
	BattleUnit.gambit_damage_dealt(credit_id, unit, dealt)
	unit.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)


## The giant ion orb: travels to `end`, hitting each enemy it passes once. It's a
## Projectile: an enemy area that slows shots (Bubbler's bubble) slows it, and an enemy that
## sends projectiles back (Glaive's spin, a parry, Balmede's plant, Wesper) turns it around.
## Sent back, it belongs to that enemy and flies on to the far edge of the board, hitting
## SEG.FAULT's side instead (the reflector excepted). It then just deals its damage: no
## marks (B1), no edge blast (B2), and it isn't SEG.FAULT's Gambit damage any more.
## Gameplay, so it runs in sims too; only its drawing is skipped there.
class CannonOrb extends Projectile:
	const OVAL := Vector2(26.0, 15.0)   # half-width and half-height of the oval
	const SPIN := 6.0                   # radians a second it turns
	var gambit: SegCannonGambit
	var caster   # untyped: may be freed
	var grid: BattleGrid
	var amount: float
	var end := Vector2.ZERO
	var dir := Vector2.RIGHT
	var reach := 50.0
	var group := 0
	var _hit_ids := {}
	var _reflected := false
	var _spin := 0.0
	var _trail: Array[Vector2] = []

	func _physics_process(delta: float) -> void:
		var from := global_position
		var left := from.distance_to(end)
		var flight := gambit.orb_speed * speed_scale()   # Bubbler's bubble slows it
		var step := minf(flight * delta, left)
		var to := from + dir * step
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or unit.team == team or not unit.is_targetable():
				continue
			if _hit_ids.has(unit.get_instance_id()):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
			if closest.distance_to(unit.global_position) > reach:
				continue
			_hit_ids[unit.get_instance_id()] = true
			if unit.try_reflect(self):
				global_position = closest   # turns around where it was sent back
				return
			_strike(unit)
		global_position = to
		if KeepsakeVfx.enabled():
			_trail.push_front(to)
			if _trail.size() > 10:
				_trail.pop_back()
			queue_redraw()
		if step >= left - 0.01:
			if not _reflected:
				_detonate()
			queue_free()

	func _strike(unit: BattleUnit) -> void:
		if not _reflected:
			gambit.hit(caster, credit_id, unit, amount)
			if group > 0 and unit.alive:
				CannonMark.mark(unit, group, gambit.mark_share, gambit.mark_duration)
			return
		var dealt := unit.take_damage(BattleUnit.damage_bonus(credit_id, unit, amount * Stats.wrack_multiplier(wrack_level, 0.3)), wrack_level, damage_type)
		get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)

	## Sent back by `by`: it turns around (or heads straight for `to`, when given: Wesper B1)
	## and flies on to the board's edge, now on `by`'s side. It rolls for wrack at
	## `wrack_chance`.
	func reflect(by: BattleUnit, wrack_chance: float, to: BattleUnit = null) -> bool:
		wrack_level = maxi(wrack_level, Stats.roll_wrack(wrack_chance))
		shooter_id = by.get_instance_id()
		credit_id = by.get_credit_id()
		team = by.team
		caster = by
		var aim := Vector2.ZERO
		if is_instance_valid(to) and to.alive and to.team != by.team:
			aim = (to.global_position - global_position).normalized()
		dir = aim if aim != Vector2.ZERO else -dir
		end = _edge_from(global_position, dir)
		_hit_ids = {by.get_instance_id(): true}
		_reflected = true
		group = 0
		return true

	## Where a line from `from` along `direction` leaves the board.
	func _edge_from(from: Vector2, direction: Vector2) -> Vector2:
		var spacing := grid.cell_spacing()
		var edge := from
		var at := from
		for i in 400:
			at += direction * spacing * 0.25
			if not grid.has_cell(grid.world_to_cell(at)):
				break
			edge = at
		return edge

	func _process(delta: float) -> void:
		_spin = wrapf(_spin + SPIN * delta, 0.0, TAU)   # only the drawing turns

	## B2: the blast at the board's edge.
	func _detonate() -> void:
		if gambit.edge_radius <= 0.0:
			return
		var spacing := grid.cell_spacing()
		SegFx.burst(get_parent(), end, (gambit.edge_radius + 0.5) * spacing)
		var edge_cell := grid.world_to_cell(end)
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or unit.team == team or not unit.is_targetable():
				continue
			if grid.get_distance(edge_cell, unit.cell) <= int(gambit.edge_radius):
				gambit.hit(caster, credit_id, unit, amount * gambit.edge_share)

	## A giant spinning white oval, like a salvo bolt, with a glow and a fading trail.
	func _draw() -> void:
		for i in _trail.size():
			var k := 1.0 - float(i) / _trail.size()
			draw_circle(to_local(_trail[i]), 12.0 * k, Color(SegFx.LIGHT, 0.25 * k))
		draw_colored_polygon(_oval(OVAL + Vector2(8.0, 8.0)), Color(SegFx.LIGHT, 0.25))
		draw_colored_polygon(_oval(OVAL + Vector2(3.0, 3.0)), Color(SegFx.LIGHT, 0.5))
		draw_colored_polygon(_oval(OVAL), SegFx.COLOR)

	func _oval(radii: Vector2) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			points.append(Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(_spin))
		return points


func _enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable():
			result.append(unit)
	return result


func _target(caster: BattleUnit) -> BattleUnit:
	var target := caster.target
	if is_instance_valid(target) and target.alive and target.is_targetable() and target.team != caster.team:
		return target
	var best: BattleUnit = null
	var best_d := 1 << 30
	for unit in _enemies(caster):
		var d := caster.grid.get_distance(caster.cell, unit.cell)
		if d < best_d or (d == best_d and unit.get_instance_id() < best.get_instance_id()):
			best = unit
			best_d = d
	return best


## B1's mark. Marks from the same blast share a group; damage one of them takes is shared
## out to the others in its group (not passed on again from there).
class CannonMark extends Status:
	static var _sharing := false
	var group: int
	var share: float
	var time_left: float

	static func mark(unit: BattleUnit, p_group: int, p_share: float, duration: float) -> void:
		var time := duration * unit.debuff_multiplier()
		for status in unit.statuses:
			if status is CannonMark:
				status.group = p_group   # the newest blast's group
				status.share = p_share
				status.time_left = maxf(status.time_left, time)
				return
		var mark_status := CannonMark.new()
		mark_status.group = p_group
		mark_status.share = p_share
		mark_status.time_left = time
		unit.add_status(mark_status)
		unit.show_float_text("Marked", SegFx.LIGHT)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		if _sharing or damage <= 0.0:
			return damage
		var passed := damage * share
		_sharing = true
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other == null or other == unit or not other.alive:
				continue
			for status in other.statuses:
				if status is CannonMark and status.group == group:
					other.take_warded_damage(passed, false, unit.incoming_damage_type)
					break
		_sharing = false
		return damage

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
