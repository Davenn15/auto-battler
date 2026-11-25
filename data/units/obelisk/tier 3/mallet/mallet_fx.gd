class_name MalletFx
extends RefCounted
## Mallet's look, shared by its Gambits: a pinkish crimson, its leaps and its landings.

const COLOR := Color(0.86, 0.12, 0.33)
const LIGHT := Color(1.0, 0.5, 0.64)


## Flies `unit` to `dest` (or hops in place) over `time`, its sprite arcing up `height`
## pixels and back down. Untargetable while airborne. Await it.
static func leap(unit: BattleUnit, dest: Vector2i, time: float, height: float) -> void:
	var airborne := UntargetableStatus.new(INF)   # removed by hand on landing
	unit.add_status(airborne)
	unit.lock_for(time + 0.05)
	if unit.sprite != null:
		var hop := unit.sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		hop.tween_property(unit.sprite, "position:y", -height, time * 0.5).as_relative() \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(unit.sprite, "position:y", height, time * 0.5).as_relative() \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if dest != unit.cell:
		await unit.dash_to(dest, time)
	else:
		await unit.get_tree().create_timer(time, true, true).timeout
	if is_instance_valid(unit):
		unit.remove_status(airborne)


## Pinpoint Strike's launch: Mallet turns to point at `target` and rockets to `dest` in a
## straight line over `time`, speeding up as it goes, trailing exhaust. If it's already
## next to the target (dest is its own cell) it rockets into it and recoils back.
## Untargetable while flying. Await it. The flight path is the same in sims (only the turn
## and the trail are skipped there), so timing never depends on what's on screen.
const ROCKET_SETTLE := 0.15   # seconds to turn back upright after landing

static func rocket(unit: BattleUnit, dest: Vector2i, target: BattleUnit, time: float) -> void:
	var airborne := UntargetableStatus.new(INF)   # removed by hand on landing
	unit.add_status(airborne)
	unit.lock_for(time + 0.05)
	var start := unit.global_position
	var aim_at := target.global_position if is_instance_valid(target) else start + Vector2.UP
	var motion := unit.melee_motion
	var showing := KeepsakeVfx.enabled() and motion != null
	if showing:
		# Nose first: the sprite's top points along the flight.
		motion.rotation = (aim_at - start).angle() - unit.global_rotation + PI / 2.0
		var trail := RocketTrail.new()
		trail.unit = unit
		trail.time_left = time
		trail.z_index = 9
		unit.get_parent().add_child(trail)
	var fly := unit.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if dest != unit.cell:
		unit.place_at(dest)   # the logical move is instant; the flight below is only the path
		var end := unit.global_position
		unit.global_position = start
		fly.tween_property(unit, "global_position", end, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var into := start.lerp(aim_at, 0.45)
		fly.tween_property(unit, "global_position", into, time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(unit, "global_position", start, time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await unit.get_tree().create_timer(time, true, true).timeout
	if not is_instance_valid(unit):
		return
	unit.remove_status(airborne)
	if showing and is_instance_valid(motion):
		motion.rotation = wrapf(motion.rotation, -PI, PI)
		motion.create_tween().tween_property(motion, "rotation", 0.0, ROCKET_SETTLE) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Exhaust puffs left behind the unit while it rockets, fading out.
class RocketTrail extends Node2D:
	const PUFF_LIFE := 0.3
	const FLAME := Color(1.0, 0.62, 0.2)
	var unit   # untyped: may be freed
	var time_left := 0.35
	var _puffs: Array = []   # [position, age]
	var _last := Vector2.INF

	func _process(delta: float) -> void:
		time_left -= delta
		for puff in _puffs:
			puff[1] += delta
		_puffs = _puffs.filter(func(p): return p[1] < PUFF_LIFE)
		if time_left > 0.0 and is_instance_valid(unit):
			var at: Vector2 = unit.global_position
			if _last == Vector2.INF or at.distance_to(_last) > 4.0:
				_puffs.append([to_local(at), 0.0])
				_last = at
		elif _puffs.is_empty():
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for puff in _puffs:
			var k: float = puff[1] / PUFF_LIFE
			draw_circle(puff[0], 9.0 * (1.0 - k) + 2.0, Color(MalletFx.COLOR, 0.35 * (1.0 - k)))
			draw_circle(puff[0], 5.0 * (1.0 - k) + 1.0, Color(FLAME, 0.8 * (1.0 - k)))


## A crimson shockwave the size of `radius_cells`, bursting out from `unit`.
static func shockwave(unit: BattleUnit, radius_cells: int) -> void:
	if not KeepsakeVfx.enabled():
		return
	var r := (radius_cells + 0.5) * unit.grid.cell_spacing()
	KeepsakeVfx.missile_blast(unit.get_parent(), unit.global_position, r, COLOR)
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = LIGHT
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.from_angle(TAU * i / 32.0) * r)
	ring.points = points
	ring.scale = Vector2.ONE * 0.2
	ring.z_index = 14
	unit.get_parent().add_child(ring)
	ring.global_position = unit.global_position
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)


## Phases `unit` for `time` seconds (see PhaseStatus). Its own Phase, so crowd control
## resistance doesn't shorten it.
static func self_phase(unit: BattleUnit, time: float) -> void:
	PhaseStatus.phase(unit, time)
