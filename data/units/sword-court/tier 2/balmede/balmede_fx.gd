class_name BalmedeFx
extends RefCounted
## Balmede's look, shared by her Gambits: a light turquoise.

const COLOR := Color(0.45, 0.92, 0.86)
const LIGHT := Color(0.8, 1.0, 0.97)


## The planted stance around `unit`: a ring on the ground with roots of light, while the
## Gambit lasts. Removed by the Gambit's status. Null when headless.
static func plant_ring(unit: BattleUnit) -> PlantRing:
	if not KeepsakeVfx.enabled() or not unit.is_inside_tree():
		return null
	var ring := PlantRing.new()
	ring.radius = unit.grid.cell_spacing() * 0.48
	ring.z_index = -1
	ring.show_behind_parent = true
	unit.add_child(ring)
	return ring


## A turquoise streak from `from` that stretches after `unit` for `time` seconds as she
## charges, then fades.
static func charge_trail(unit: BattleUnit, from: Vector2, time: float) -> void:
	if not KeepsakeVfx.enabled() or not unit.is_inside_tree():
		return
	var trail := ChargeTrail.new()
	trail.unit = unit
	trail.from = from
	trail.time_left = time
	trail.z_index = 11
	unit.get_parent().add_child(trail)


## The charge streak: drawn from where she started to where she is, until she arrives,
## then it fades out.
class ChargeTrail extends Node2D:
	const FADE := 0.4
	var unit   # untyped: may be freed
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var time_left := 0.5
	var _fade := FADE

	func _process(delta: float) -> void:
		if time_left > 0.0 and is_instance_valid(unit):
			time_left -= delta
			to = unit.global_position
		else:
			_fade -= delta
			if _fade <= 0.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		if to == Vector2.ZERO:
			return
		var alpha := clampf(_fade / FADE, 0.0, 1.0)
		var a := to_local(from)
		var b := to_local(to)
		draw_line(a, b, Color(BalmedeFx.COLOR, 0.35 * alpha), 16.0, true)
		draw_line(a, b, Color(BalmedeFx.LIGHT, alpha), 5.0, true)
		draw_circle(a, 8.0, Color(BalmedeFx.COLOR, 0.35 * alpha))
		draw_circle(b, 8.0, Color(BalmedeFx.COLOR, 0.35 * alpha))


## The planted ring: a pulsing circle with short roots reaching out from it.
class PlantRing extends Node2D:
	var radius := 30.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(Vector2(0, radius * 0.35), radius, Color(BalmedeFx.COLOR, 0.12 + 0.06 * pulse))
		draw_arc(Vector2(0, radius * 0.35), radius, 0.0, TAU, 40, Color(BalmedeFx.COLOR, 0.8), 2.0, true)
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			var from := Vector2(0, radius * 0.35) + Vector2.from_angle(a) * radius
			draw_line(from, from + Vector2.from_angle(a) * (5.0 + 3.0 * pulse), Color(BalmedeFx.LIGHT, 0.7), 1.5, true)
