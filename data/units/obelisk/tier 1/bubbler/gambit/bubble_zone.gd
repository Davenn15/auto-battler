class_name BubbleZone
extends Node2D
## Bubbler's protective bubble: a dome over the cells within Radius Cells of where he cast
## it. It stays put for its duration. While it lasts:
##   - allies inside gain wards (all three);
##   - Warding (A): allies inside slowly build a shield;
##   - A1: enemy shots inside it fly slower;
##   - A2: enemies inside lose Celerity.
## Everything it needs is copied in when it's cast, so it keeps going if Bubbler dies.

const PULSE := 1.0   # seconds between Warding's shield top-ups

var team: int
var caster_id: int
var grid: BattleGrid
var center: Vector2i
var radius_cells: int
var time_left: float
var ward_bonus: float
var shield_per_second: float      # Warding: shield given each second to allies inside
var shield_duration: float
var projectile_slow: float        # A1: enemy shots inside move at this share of their speed (1 = no slow)
var enemy_celerity_cut: float     # A2: Celerity enemies inside lose
var _pulse_left := PULSE
var _time := 0.0


func setup(caster: BattleUnit, p_radius: int, p_duration: float, p_ward: float) -> void:
	team = caster.team
	caster_id = caster.get_instance_id()
	grid = caster.grid
	center = caster.cell
	radius_cells = p_radius
	time_left = p_duration
	ward_bonus = p_ward
	z_index = -1   # under the units
	add_to_group("projectile_slowers")


func contains(unit: BattleUnit) -> bool:
	return grid.get_distance(center, unit.cell) <= radius_cells


func _radius_pixels() -> float:
	return (radius_cells + 0.5) * grid.cell_spacing()


## For shots (see Projectile.speed_scale): enemy shots inside move at projectile_slow speed.
func slow_factor(point: Vector2, shot_team: int) -> float:
	if shot_team == team or projectile_slow >= 1.0:
		return 1.0
	return projectile_slow if global_position.distance_to(point) <= _radius_pixels() else 1.0


func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	_pulse_left -= delta
	var pulse := _pulse_left <= 0.0
	if pulse:
		_pulse_left += PULSE
	var key := get_instance_id()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or not contains(unit):
			continue
		if unit.team == team:
			BubbleStatus.refresh_on(unit, key, ward_bonus, 0.0)
			if pulse and shield_per_second > 0.0:
				unit.add_shield(shield_per_second * PULSE, shield_duration, caster_id if is_instance_id_valid(caster_id) else 0)
		elif enemy_celerity_cut > 0.0:
			BubbleStatus.refresh_on(unit, key, 0.0, enemy_celerity_cut)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## A see-through dome with a softly wobbling rim.
func _draw() -> void:
	var r := _radius_pixels()
	var fade := clampf(time_left / 0.4, 0.0, 1.0) * clampf(_time / 0.25, 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(BUBBLE_COLOR, 0.13 * fade))
	var points := PackedVector2Array()
	for i in 73:
		var angle := TAU * i / 72.0
		points.append(Vector2.from_angle(angle) * (r + 2.0 * sin(angle * 6.0 + _time * 3.0)))
	draw_polyline(points, Color(BUBBLE_COLOR, 0.75 * fade), 2.0, true)
	draw_arc(Vector2(-r * 0.35, -r * 0.35), r * 0.25, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.35 * fade), 3.0, true)   # a glint


const BUBBLE_COLOR := Color(1.0, 0.6, 0.2)   # Bubbler's orange: the dome, Popping bubbles and their pops
