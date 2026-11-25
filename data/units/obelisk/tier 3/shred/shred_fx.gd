class_name ShredFx
extends RefCounted
## Shred's look: a slightly pinkish coral red.

const COLOR := Color(0.97, 0.42, 0.46)
const LIGHT := Color(1.0, 0.72, 0.72)


## B1: a burst of shrapnel streaking from `from` to `to_unit`.
static func shrapnel(from: Vector2, to_unit: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(to_unit):
		return
	var burst := Shrapnel.new()
	burst.start = from
	burst.end = to_unit.global_position
	burst.z_index = 11
	to_unit.get_tree().current_scene.add_child(burst)
	burst.global_position = Vector2.ZERO


## A quick dash streak from `from` to `to` (both Gambits).
static func dash_streak(unit: BattleUnit, from: Vector2, to: Vector2) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or from.distance_to(to) < 2.0:
		return
	var streak := Line2D.new()
	streak.points = PackedVector2Array([from, to])
	streak.width = 6.0
	streak.default_color = Color(COLOR, 0.6)
	streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
	streak.end_cap_mode = Line2D.LINE_CAP_ROUND
	streak.z_index = 4
	unit.get_tree().current_scene.add_child(streak)
	streak.global_position = Vector2.ZERO
	var tween := streak.create_tween()
	tween.tween_property(streak, "modulate:a", 0.0, 0.35)
	tween.tween_callback(streak.queue_free)


class Shrapnel extends Node2D:
	const TIME := 0.18
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var _age := 0.0
	var _offsets: Array[Vector2] = []

	func _ready() -> void:
		var side := (end - start).orthogonal().normalized()
		for i in 4:
			_offsets.append(side * (i - 1.5) * 4.0)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME + 0.12:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := minf(_age / TIME, 1.0)
		var fade := 1.0 - maxf(_age - TIME, 0.0) / 0.12
		for i in _offsets.size():
			var lag := i * 0.08
			var head := start.lerp(end, clampf(t - lag, 0.0, 1.0)) + _offsets[i] * (1.0 - t)
			var tail := start.lerp(end, clampf(t - lag - 0.2, 0.0, 1.0)) + _offsets[i] * (1.0 - t)
			draw_line(tail, head, Color(ShredFx.LIGHT, 0.9 * fade), 2.0, true)
			draw_circle(head, 2.0, Color(ShredFx.COLOR, fade))
