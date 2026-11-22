class_name ByteFx
extends RefCounted
## BYTE's look: deep blue.

const COLOR := Color(0.1, 0.22, 0.72)    # deep blue
const LIGHT := Color(0.42, 0.6, 1.0)


## The concussive ripple: rings spreading out on the ground under `target`.
static func ripple(target: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(target):
		return
	var rings := Ripple.new()
	KeepsakeVfx._ground(target).add_child(rings)
	rings.global_position = target.global_position


## Buffeting: a wedge flashing out from `caster` along `aim` (radians, on screen),
## `reach` pixels long and `half_angle` radians either side.
static func cone(caster: BattleUnit, aim: float, reach: float, half_angle: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(caster):
		return
	var wedge := Wedge.new()
	wedge.aim = aim
	wedge.reach = reach
	wedge.half_angle = half_angle
	wedge.z_index = 8
	caster.get_tree().current_scene.add_child(wedge)
	wedge.global_position = caster.global_position


## B2: a small healing orb flying from `from` to `ally`.
static func splash(from: Vector2, ally: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(ally):
		return
	var orb := Orb.new()
	orb.target = ally
	orb.z_index = 12
	ally.get_tree().current_scene.add_child(orb)
	orb.global_position = from


class Ripple extends Node2D:
	const TIME := 0.5
	const RADIUS := 34.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / TIME
		for i in 3:
			var k := clampf(t * 1.6 - i * 0.3, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var fade := 1.0 - k
			draw_arc(Vector2.ZERO, RADIUS * k, 0.0, TAU, 40, Color(ByteFx.LIGHT, 0.9 * fade), 3.0 * fade + 1.0, true)
		draw_circle(Vector2.ZERO, RADIUS * 0.35 * (1.0 - t), Color(ByteFx.COLOR, 0.5 * (1.0 - t)))


class Wedge extends Node2D:
	const TIME := 0.35
	var aim := 0.0
	var reach := 80.0
	var half_angle := 0.8
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / TIME
		var r := reach * (0.4 + 0.6 * minf(t * 2.0, 1.0))
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := aim - half_angle + 2.0 * half_angle * i / 12.0
			points.append(Vector2.from_angle(a) * r)
		var fade := 1.0 - t
		draw_colored_polygon(points, Color(ByteFx.COLOR, 0.35 * fade))
		draw_polyline(points.slice(1), Color(ByteFx.LIGHT, 0.85 * fade), 2.5, true)


class Orb extends Node2D:
	const SPEED := 420.0
	var target   # untyped: may be freed

	func _process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			queue_free()
			return
		var to: Vector2 = target.global_position - global_position
		if to.length() <= SPEED * delta:
			queue_free()
			return
		global_position += to.normalized() * SPEED * delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6.0, Color(ByteFx.LIGHT, 0.35))
		draw_circle(Vector2.ZERO, 3.5, Color(0.6, 1.0, 0.75))
