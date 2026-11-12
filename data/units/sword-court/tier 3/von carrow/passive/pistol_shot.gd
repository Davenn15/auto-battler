class_name PistolShot
extends Projectile
## Von Carrow's pistol shot: a normal attack projectile drawn as a bullet with a short
## streak behind it. Firing it flashes and puffs smoke at the muzzle (MuzzleFlash).

const BULLET_COLOR := Color(1.0, 0.85, 0.5)   # brass
const TRAIL_LENGTH := 16.0


func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	super.setup(p_shooter, p_target, p_damage, p_color, p_wrack_level, p_type, p_hit_effects)
	# A bullet: a long body with a rounded nose, pointing right (+x is where it flies).
	polygon = PackedVector2Array([
		Vector2(-7, -3), Vector2(4, -3), Vector2(7, -2), Vector2(9, 0),
		Vector2(7, 2), Vector2(4, 3), Vector2(-7, 3)])
	color = BULLET_COLOR.lerp(p_color, 0.35)   # still tinted by its damage type and wracks
	if KeepsakeVfx.enabled() and is_instance_valid(p_target) and p_shooter.is_inside_tree():
		var flash := MuzzleFlash.new()
		flash.z_index = 15
		flash.rotation = (p_target.global_position - p_shooter.global_position).angle()
		p_shooter.get_tree().current_scene.add_child(flash)
		flash.global_position = p_shooter.global_position + Vector2.from_angle(flash.rotation) * 18.0


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		rotation = (target.global_position - global_position).angle()   # point where it's flying
	super._physics_process(delta)


func _draw() -> void:
	# The streak behind the bullet, fading out (drawn under the bullet's own polygon).
	draw_line(Vector2(-7, 0), Vector2(-7 - TRAIL_LENGTH, 0), Color(1, 0.95, 0.8, 0.45), 3.0, true)
	draw_line(Vector2(-7, 0), Vector2(-7 - TRAIL_LENGTH * 0.5, 0), Color(1, 1, 1, 0.6), 1.5, true)


## The gunshot: a bright starburst at the muzzle that shrinks fast, and a puff of smoke
## that drifts and fades.
class MuzzleFlash extends Node2D:
	const LIFE := 0.3
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / LIFE
		# Flash: only the first third of its life.
		var flash := clampf(1.0 - t * 3.0, 0.0, 1.0)
		if flash > 0.0:
			var points := PackedVector2Array()
			for i in 10:
				var reach := (16.0 if i % 2 == 0 else 6.0) * (0.6 + 0.4 * flash)
				if i == 0:
					reach *= 1.6   # the long spike points along the shot
				points.append(Vector2.from_angle(TAU * i / 10.0) * reach)
			draw_colored_polygon(points, Color(1.0, 0.85, 0.4, flash))
			draw_circle(Vector2.ZERO, 5.0 * flash, Color(1, 1, 1, flash))
		# Smoke: grows and drifts forward and up as it fades.
		var smoke := 1.0 - t
		for i in 3:
			var offset := Vector2(6.0 + 10.0 * t + i * 5.0, (i - 1) * 4.0 - 6.0 * t)
			draw_circle(offset, 3.0 + 6.0 * t + i, Color(0.8, 0.8, 0.8, 0.35 * smoke))
