class_name ParryStanceStatus
extends Status
## Extra wards and a chance to send incoming projectiles back, for a while.

const PARRY_COLOR := Color(0.85, 0.85, 0.95)

var time_left: float
var ward_bonus: float
var celerity_bonus: float
var reflect_chance: float
var reflect_wrack_bonus: float
## B1: deflected projectiles fly at her current target (back at the shooter if she has none).
var deflect_to_target := false
var _visual: StanceGuard


func _init(p_duration: float, p_ward_bonus: float, p_celerity_bonus: float, p_reflect_chance: float, p_reflect_wrack_bonus: float) -> void:
	time_left = p_duration
	ward_bonus = p_ward_bonus
	celerity_bonus = p_celerity_bonus
	reflect_chance = p_reflect_chance
	reflect_wrack_bonus = p_reflect_wrack_bonus


func on_applied(unit: BattleUnit) -> void:
	if KeepsakeVfx.enabled():
		_visual = StanceGuard.new()
		var size := KeepsakeVfx._sprite_size(unit)
		_visual.radius = maxf(size.x * 0.62, 22.0)
		_visual.feet = maxf(size.y * 0.5, 16.0)
		_visual.z_index = 11
		unit.add_child(_visual)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_visual):
		_visual.finish()


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if is_instance_valid(_visual):
		_visual.ending = time_left < 0.6
	if time_left <= 0.0:
		unit.remove_status(self)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
		return value + ward_bonus
	if stat == Stats.Stat.CELERITY:
		return value + celerity_bonus
	return value


func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
	if CombatRng.randf() >= reflect_chance:
		return false
	var wrack_chance := unit.get_stat(Stats.Stat.WRACK_CHANCE) + reflect_wrack_bonus
	var to: BattleUnit = unit.target if deflect_to_target and unit._is_valid_target(unit.target) else null
	if not projectile.reflect(unit, wrack_chance, to):
		return false
	unit.show_float_text("Parry", PARRY_COLOR)
	if is_instance_valid(_visual):
		_visual.flash(projectile.global_position - unit.global_position)
	return true


## Parry Stance's look while it lasts: two pale silver guard arcs circling Wesper on a faint
## ring at her feet, flickering as it runs out. A parry flashes a bright arc on the side
## the projectile came from.
class StanceGuard extends Node2D:
	const COLOR := Color(0.85, 0.87, 1.0)
	const FADE_IN := 0.18
	var radius := 26.0
	var feet := 24.0   # how far below her centre the ground ring sits
	var ending := false
	var _time := 0.0
	var _out := -1.0              # >= 0 while fading out after the stance ends
	var _flash_dir := Vector2.RIGHT
	var _flash := 0.0

	func flash(direction: Vector2) -> void:
		if direction.length() > 0.01:
			_flash_dir = direction.normalized()
		_flash = 1.0

	func finish() -> void:
		if _out < 0.0:
			_out = 0.0

	func _process(delta: float) -> void:
		_time += delta
		_flash = maxf(0.0, _flash - delta * 4.0)
		if _out >= 0.0:
			_out += delta
			if _out >= 0.25:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var a := clampf(_time / FADE_IN, 0.0, 1.0)
		if _out >= 0.0:
			a *= 1.0 - _out / 0.25
		if ending:   # flickers in its last moments
			a *= 0.55 + 0.45 * absf(sin(_time * 14.0))
		var squash := 0.38
		# The ring at her feet.
		draw_set_transform(Vector2(0, feet), 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 40, Color(COLOR, 0.5 * a), 2.5)
		# Two guard arcs sweeping around her, on a tilted circle (front half brighter).
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.55))
		for k in 2:
			var start := _time * 2.4 + k * PI
			var steps := 10
			for i in steps:
				var t0 := start + i * 0.11
				var t1 := t0 + 0.11
				var front := 0.5 + 0.5 * sin((t0 + t1) / 2.0)   # bottom of the circle = in front of her
				var w := 1.0 - float(i) / steps                   # the arc's tail fades
				draw_arc(Vector2.ZERO, radius, t0, t1, 3,
						Color(COLOR, (0.4 + 0.6 * front) * w * a), 2.5 + 1.5 * front)
		draw_set_transform(Vector2.ZERO)
		# A parry: a bright crescent on the side the shot came from.
		if _flash > 0.0:
			var angle := _flash_dir.angle()
			var r := radius * (1.0 + 0.25 * (1.0 - _flash))
			draw_arc(Vector2.ZERO, r, angle - 0.7, angle + 0.7, 16, Color(1, 1, 1, 0.9 * _flash * a), 3.0)
			draw_arc(Vector2.ZERO, r - 4.0, angle - 0.5, angle + 0.5, 12, Color(COLOR, 0.6 * _flash * a), 2.0)
