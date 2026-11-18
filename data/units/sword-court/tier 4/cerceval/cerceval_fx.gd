class_name CercevalFx
extends RefCounted
## Cerceval's look: pale pink barbed blades.

const COLOR := Color(1.0, 0.76, 0.84)     # pale pink
const DEEP := Color(0.86, 0.38, 0.52)      # the blades' darker edge
const FRENZY_GLOW := "VfxBarbedFrenzy"


## Thorn Waltz: a ring of blades spinning out around him and fading.
static func waltz(unit: BattleUnit, radius: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	var ring := WaltzRing.new()
	ring.radius = radius
	ring.z_index = 12
	unit.get_parent().add_child(ring)
	ring.global_position = unit.global_position


## Bloodletter's heal: a few small drops of blood running from a Bleeding enemy to him
## along a gentle arc, fading as they arrive.
static func blood_trail(from: BattleUnit, to: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(from) or not is_instance_valid(to) or not to.is_inside_tree():
		return
	var trail := BloodTrail.new()
	trail.from_unit = from
	trail.to_unit = to
	trail.start = from.global_position
	trail.end = to.global_position
	trail.bend = 1.0 if randf() < 0.5 else -1.0
	trail.z_index = 11
	to.get_parent().add_child(trail)


class BloodTrail extends Node2D:
	const TIME := 0.55        # each drop's run
	const DROPS := 6
	const STAGGER := 0.05     # between drops
	const ARC := 0.18         # how far the path bows out, as a share of its length
	var from_unit   # untyped: may be freed; the ends follow the units while they live
	var to_unit
	var start: Vector2
	var end: Vector2
	var bend := 1.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if is_instance_valid(from_unit):
			start = from_unit.global_position
		if is_instance_valid(to_unit):
			end = to_unit.global_position
		if _time >= TIME + STAGGER * DROPS:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := to_local(start)
		var b := to_local(end)
		var mid := (a + b) / 2.0 + (b - a).orthogonal() * ARC * bend
		for i in DROPS:
			var t := clampf((_time - i * STAGGER) / TIME, 0.0, 1.0)
			if t <= 0.0 or t >= 1.0:
				continue
			var eased := t * t * (3.0 - 2.0 * t)   # starts and ends gently
			var p := a.lerp(mid, eased).lerp(mid.lerp(b, eased), eased)
			var fade := sin(t * PI)   # fades in, then out as it arrives
			var radius := lerpf(2.2, 1.2, float(i) / DROPS)
			draw_circle(p, radius, Color(Bleed.COLOR, 0.75 * fade))


class WaltzRing extends Node2D:
	const TIME := 0.45
	const BLADES := 6
	var radius := 40.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_time / TIME, 0.0, 1.0)
		var fade := 1.0 - t * t
		var r := radius * (0.55 + 0.45 * t)
		var spin := t * TAU * 1.5
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(CercevalFx.COLOR, 0.25 * fade), 2.0, true)
		for i in BLADES:
			var angle := spin + TAU * i / BLADES
			var dir := Vector2.from_angle(angle)
			var side := dir.orthogonal()
			var tip := dir * r
			draw_colored_polygon(PackedVector2Array([tip + side * 9.0, tip + dir * 3.0, tip - side * 2.0, tip - dir * 4.0]),
					Color(CercevalFx.COLOR, 0.9 * fade))
