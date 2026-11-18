class_name BrogaineFx
extends RefCounted
## Brogaine's look: dirty golden yellow.

const COLOR := Color(0.80, 0.66, 0.26)     # dirty golden yellow
const DEEP := Color(0.55, 0.42, 0.12)      # its darker edge


## Flex: a golden ring swelling out from him.
static func flex(unit: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	var ring := Pulse.new()
	ring.radius = unit.grid.cell_spacing() * 0.55
	ring.z_index = 12
	unit.get_parent().add_child(ring)
	ring.global_position = unit.global_position


## The uppercut: a short golden arc sweeping up through the target.
static func uppercut(unit: BattleUnit, target: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or not is_instance_valid(target) or not unit.is_inside_tree():
		return
	var arc := Uppercut.new()
	arc.size = unit.grid.cell_spacing() * 0.45
	arc.z_index = 12
	unit.get_parent().add_child(arc)
	arc.global_position = target.global_position


## Rowdy's duel: a pulsing gold ring under each duellist and a bright gold line joining
## them while it lasts, plus crossed fists over the pair as it starts. Frees itself once
## `status` is no longer on `a`.
static func duel(a: BattleUnit, b: BattleUnit, status: Status) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(a) or not a.is_inside_tree():
		return
	var ground := DuelGround.new()
	ground.a = a
	ground.b = b
	ground.status = status
	ground.radius = a.grid.cell_spacing() * 0.42
	ground.z_index = -1   # on the ground, under the units
	a.get_parent().add_child(ground)
	var fists := CrossedFists.new()
	fists.size = a.grid.cell_spacing() * 0.3
	fists.z_index = 12
	a.get_parent().add_child(fists)
	fists.global_position = (a.global_position + b.global_position) / 2.0 + Vector2(0, -a.grid.cell_spacing() * 0.35)


## Hearty's aura: a faint gold ring at his reach, drawn like Lunck's Rally aura, and gold
## motes drifting up from allies standing in it (only during combat; they stop once
## `status` is no longer on him).
static func aura(unit: BattleUnit, status: Status, radius: int) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	KeepsakeVfx._range_aura(unit, "VfxHearty", radius, false, COLOR, KeepsakeVfx.RALLY_STRENGTH)
	var motes := AuraMotes.new()
	motes.unit = unit
	motes.status = status
	motes.radius = radius
	motes.z_index = 12
	unit.get_parent().add_child(motes)


class Pulse extends Node2D:
	const TIME := 0.5
	var radius := 30.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_time / TIME, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(Vector2.ZERO, radius * (0.6 + 0.6 * eased), 0.0, TAU, 40, Color(BrogaineFx.COLOR, 0.8 * (1.0 - t)), 3.0, true)
		draw_arc(Vector2.ZERO, radius * (0.4 + 0.5 * eased), 0.0, TAU, 40, Color(BrogaineFx.DEEP, 0.5 * (1.0 - t)), 2.0, true)


class Uppercut extends Node2D:
	const TIME := 0.3
	var size := 20.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_time / TIME, 0.0, 1.0)
		# A crescent sweeping from low-left up to high-right.
		var sweep := lerpf(0.0, 1.0, 1.0 - pow(1.0 - t, 2.0))
		var start := PI * 0.85
		var finish := start + PI * 0.9 * sweep
		draw_arc(Vector2(0, size * 0.3), size, start, finish, 16, Color(BrogaineFx.COLOR, 0.9 * (1.0 - t * t)), 4.0, true)


class DuelGround extends Node2D:
	const FADE_IN := 0.2
	var a   # untyped: may be freed
	var b
	var status: Status
	var radius := 24.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if not is_instance_valid(a) or not is_instance_valid(b) or not a.alive or not b.alive or not a.statuses.has(status):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(_time / FADE_IN, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		var p := to_local(a.global_position)
		var q := to_local(b.global_position)
		# The tether: a soft wide glow with a bright core, stopping at each ring.
		var dir := (q - p).normalized()
		if p.distance_to(q) > radius * 2.0:
			var from := p + dir * radius
			var to := q - dir * radius
			draw_line(from, to, Color(BrogaineFx.COLOR, 0.25 * fade), 7.0, true)
			draw_line(from, to, Color(BrogaineFx.COLOR.lightened(0.35), (0.75 + 0.2 * pulse) * fade), 2.5, true)
		for at in [p, q]:
			draw_arc(at, radius * (0.95 + 0.06 * pulse), 0.0, TAU, 40, Color(BrogaineFx.COLOR, (0.6 + 0.3 * pulse) * fade), 3.0, true)
			draw_arc(at, radius * 0.8, 0.0, TAU, 40, Color(BrogaineFx.DEEP, 0.35 * fade), 1.5, true)


## Two fists crossing over the duellists as the duel starts: they swing in, hold, and fade.
class CrossedFists extends Node2D:
	const TIME := 0.9
	var size := 16.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_time / TIME, 0.0, 1.0)
		var swing := 1.0 - pow(1.0 - clampf(t / 0.3, 0.0, 1.0), 3.0)   # in over the first third
		var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		var pop := 1.0 + 0.25 * sin(clampf(t / 0.3, 0.0, 1.0) * PI)
		for side in [-1.0, 1.0]:
			# Each arm runs from a lower corner up across the middle; its fist sits at the top.
			var angle: float = side * lerpf(PI * 0.5, PI * 0.25, swing)
			var dir := Vector2(-sin(angle), -cos(angle))
			var base := -dir * size
			var fist := dir * size * 0.9 * pop
			draw_line(base, fist, Color(BrogaineFx.DEEP, alpha), 5.0, true)
			draw_line(base, fist, Color(BrogaineFx.COLOR, alpha), 3.0, true)
			draw_circle(fist, size * 0.32 * pop, Color(BrogaineFx.DEEP, alpha))
			draw_circle(fist, size * 0.25 * pop, Color(BrogaineFx.COLOR.lightened(0.2), alpha))


## Small gold motes rising from each ally in his reach.
class AuraMotes extends Node2D:
	const EVERY := 0.3    # seconds between motes, per ally
	const LIFE := 1.1
	const RISE := 26.0
	var unit   # untyped: may be freed
	var status: Status
	var radius := 1
	var _clock := 0.0
	var _motes := []      # {pos: Vector2 (world), age: float}
	var _rng := RandomNumberGenerator.new()   # its own, so it never touches combat rolls

	func _process(delta: float) -> void:
		if not is_instance_valid(unit) or not unit.alive or not unit.statuses.has(status):
			queue_free()
			return
		_clock -= delta
		if _clock <= 0.0 and unit.active:
			_clock = EVERY
			var half: float = unit.grid.cell_spacing() * 0.25
			for ally in HeartyAuraPassive.allies_near(unit, radius):
				_motes.append({"pos": ally.global_position + Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half * 0.5, half)), "age": 0.0})
		for mote in _motes:
			mote["age"] += delta
		_motes = _motes.filter(func(m): return m["age"] < LIFE)
		queue_redraw()

	func _draw() -> void:
		for mote in _motes:
			var t: float = mote["age"] / LIFE
			var p: Vector2 = to_local(mote["pos"]) + Vector2(0, -RISE * t)
			var alpha := sin(t * PI)
			draw_circle(p, 6.0, Color(BrogaineFx.COLOR, 0.3 * alpha))   # soft glow
			draw_circle(p, 3.2, Color(BrogaineFx.COLOR.lightened(0.35), 0.95 * alpha))
