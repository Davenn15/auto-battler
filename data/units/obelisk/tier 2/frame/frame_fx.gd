class_name FrameFx
extends RefCounted
## Frame's look: dark teal-green.

const COLOR := Color(0.12, 0.5, 0.44)        # dark teal-green
const LIGHT := Color(0.35, 0.8, 0.7)


## Frame's legs extending: its sprite stretches up to `height` times as tall (a touch
## thinner), feet staying planted, over STRETCH_TIME. stretch(unit, 1.0) brings it back.
const STRETCH_TIME := 0.25
const STRETCH_META := &"frame_stretch_base"


static func stretch(unit: BattleUnit, height: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or unit.sprite == null:
		return
	var sprite := unit.sprite
	if not sprite.has_meta(STRETCH_META):   # its unstretched size, kept for the whole fight
		sprite.set_meta(STRETCH_META, [sprite.scale, sprite.position])
	var base: Array = sprite.get_meta(STRETCH_META)
	var base_scale: Vector2 = base[0]
	var base_pos: Vector2 = base[1]
	var tex_height: float = float(sprite.texture.get_height()) if sprite.texture != null else 64.0
	var thin := lerpf(1.0, 0.9, clampf(height - 1.0, 0.0, 1.0))
	var to_scale := Vector2(base_scale.x * thin, base_scale.y * height)
	var to_pos := base_pos - Vector2(0, tex_height * base_scale.y * (height - 1.0) / 2.0)   # feet stay put
	var tween := sprite.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", to_scale, STRETCH_TIME)
	tween.tween_property(sprite, "position", to_pos, STRETCH_TIME)


## Compassing: a teal line from Frame to the ally it's following, gone when the follow ends.
static func follow_line(frame: BattleUnit, ally: BattleUnit, status: Status) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(frame) or not frame.is_inside_tree():
		return
	var line := FollowLine.new()
	line.a = frame
	line.b = ally
	line.status = status
	line.z_index = -1   # on the ground, under the units
	frame.get_parent().add_child(line)


class FollowLine extends Node2D:
	var a   # untyped: may be freed
	var b
	var status: Status
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if not is_instance_valid(a) or not is_instance_valid(b) or not a.alive or not b.alive \
				or not a.statuses.has(status):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var glow := 0.45 + 0.2 * sin(_time * 5.0)
		draw_line(to_local(a.global_position), to_local(b.global_position), Color(FrameFx.LIGHT, glow), 2.0, true)
		draw_circle(to_local(b.global_position), 4.0, Color(FrameFx.LIGHT, glow))
