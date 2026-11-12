class_name BarrageMissile
extends Node2D
## One of BAR.RAJ's missiles: waits `delay` seconds, then arcs from where it was fired to a
## point on the ground and explodes, damaging every enemy within `blast_radius` pixels.
## Everything it needs is copied in at fire time, so it keeps flying if he dies.

const SPEED := 420.0        # pixels/sec along the ground
const ARC_HEIGHT := 0.35    # how high it arcs, as a share of the distance flown
const COLOR := Color(0.3, 0.85, 1.0)   # cyan blue

var shooter   # untyped: he may be freed while it's in the air
var credit_id: int
var team: int
var target_point: Vector2
var blast_radius: float
var damage: float
var damage_type: int
var wrack_level: int = 0
var delay: float = 0.0
var _start: Vector2
var _progress := 0.0   # 0 at launch, 1 on landing
var _flight := 1.0     # seconds the flight takes
var _flying := false


## `from` is where it's fired from. Damage is per enemy caught, wrack already applied.
func setup(p_shooter: BattleUnit, from: Vector2, to: Vector2, p_radius: float, p_damage: float,
		p_type: int, p_wrack_level: int, p_delay: float) -> void:
	shooter = p_shooter
	credit_id = p_shooter.get_credit_id()
	team = p_shooter.team
	_start = from
	target_point = to
	blast_radius = p_radius
	damage = p_damage
	damage_type = p_type
	wrack_level = p_wrack_level
	delay = p_delay
	_flight = maxf(from.distance_to(to) / SPEED, 0.15)
	z_index = 12
	visible = false


func _physics_process(delta: float) -> void:
	if not _flying:
		delay -= delta
		if delay > 0.0:
			return
		_flying = true
		visible = true
	_progress += delta / _flight * _speed_scale()
	if _progress >= 1.0:
		_explode()
		return
	global_position = _point_at(_progress)


## Where the missile is at `t` (0..1) along its arc. The arc is drawn "up" the screen.
func _point_at(t: float) -> Vector2:
	var lift := sin(t * PI) * _start.distance_to(target_point) * ARC_HEIGHT
	return _start.lerp(target_point, t) + Vector2.UP * lift


## BUBL(R)'s Warding bubble (B path) slows enemy missiles too.
func _speed_scale() -> float:
	var factor := 1.0
	for node in get_tree().get_nodes_in_group("projectile_slowers"):
		factor = minf(factor, node.slow_factor(global_position, team))
	return factor


func _explode() -> void:
	var attacker := shooter as BattleUnit if is_instance_valid(shooter) else null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == team:
			continue
		if unit.global_position.distance_to(target_point) <= blast_radius:
			var dealt := unit.take_damage(damage, wrack_level, damage_type, false, attacker)
			get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	KeepsakeVfx.missile_blast(get_parent(), target_point, blast_radius, COLOR)
	queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _flying:
		return
	# A short trail back along the arc, then the missile pointing where it's going.
	var here := global_position
	var behind := _point_at(maxf(_progress - 0.12, 0.0))
	var ahead := _point_at(minf(_progress + 0.02, 1.0))
	draw_line(to_local(behind), Vector2.ZERO, Color(COLOR, 0.35), 3.0, true)
	var dir := (ahead - here).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var side := dir.orthogonal() * 2.5
	draw_colored_polygon(PackedVector2Array([dir * 6.0, -dir * 5.0 + side, -dir * 5.0 - side]), COLOR)
