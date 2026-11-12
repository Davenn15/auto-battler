class_name InjectorMissile
extends Node2D
## One of BAR.RAJ's injector missiles: flies straight for `reach` pixels and hits the first
## enemy it touches (or the first `hits_left` with B1's pierce), dealing damage and giving
## each one Mono-Virus stacks. Copied in at fire time, so it keeps flying if he dies.

const SPEED := 520.0   # pixels/sec
const HIT_RADIUS := 16.0
const COLOR := Color(0.3, 0.85, 1.0)   # cyan blue, like his Barrage missiles
const TRAIL_LENGTH := 12   # frames of trail kept

var shooter   # untyped: he may be freed while it's in the air
var credit_id: int
var team: int
var direction: Vector2
var remaining: float
var damage: float
var damage_type: int
var wrack_level: int = 0
var virus_stacks: int = 1
var hits_left: int = 1
var delay: float = 0.0
var _hit_ids := {}
var _trail: Array[Vector2] = []


func setup(p_shooter: BattleUnit, p_direction: Vector2, p_reach: float, p_damage: float,
		p_type: int, p_wrack_level: int, p_stacks: int, p_hits: int, p_delay: float) -> void:
	shooter = p_shooter
	credit_id = p_shooter.get_credit_id()
	team = p_shooter.team
	direction = p_direction
	remaining = p_reach
	damage = p_damage
	damage_type = p_type
	wrack_level = p_wrack_level
	virus_stacks = p_stacks
	hits_left = p_hits
	delay = p_delay
	z_index = 12
	visible = false


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	visible = true
	var step := minf(SPEED * delta * _speed_scale(), remaining)
	var from := global_position
	var to := from + direction * step
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == team or _hit_ids.has(unit.get_instance_id()):
			continue
		# Distance to the segment flown this frame, so a fast missile can't skip past anyone.
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) <= HIT_RADIUS:
			_hit_ids[unit.get_instance_id()] = true
			_hit(unit)
			hits_left -= 1
			if hits_left <= 0:
				queue_free()
				return
	global_position = to
	remaining -= step
	if remaining <= 0.0:
		queue_free()


func _hit(unit: BattleUnit) -> void:
	var attacker := shooter as BattleUnit if is_instance_valid(shooter) else null
	var dealt := unit.take_damage(damage, wrack_level, damage_type, false, attacker)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	if dealt > 0.0 and unit.alive:   # a dodged missile injects nothing
		MonoVirusStatus.infect(unit, virus_stacks, credit_id)
	KeepsakeVfx.missile_blast(get_parent(), unit.global_position, 16.0, MonoVirusStatus.SETTINGS.color)


## BUBL(R)'s Warding bubble (B path) slows enemy missiles too.
func _speed_scale() -> float:
	var factor := 1.0
	for node in get_tree().get_nodes_in_group("projectile_slowers"):
		factor = minf(factor, node.slow_factor(global_position, team))
	return factor


func _process(_delta: float) -> void:
	if visible:
		_trail.push_front(global_position)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# A tapering poisonous trail, with a few droplets of virus along it.
	for i in _trail.size() - 1:
		var fade := 1.0 - float(i) / TRAIL_LENGTH
		draw_line(to_local(_trail[i]), to_local(_trail[i + 1]), Color(MonoVirusStatus.SETTINGS.color, 0.75 * fade), 1.0 + 4.0 * fade, true)
		if i % 3 == 2:
			draw_circle(to_local(_trail[i]) + direction.orthogonal() * (2.5 if i % 2 == 0 else -2.5), 1.6 * fade + 0.6, Color(MonoVirusStatus.SETTINGS.color, 0.9 * fade))
	var side := direction.orthogonal() * 2.5
	draw_colored_polygon(PackedVector2Array([direction * 7.0, -direction * 5.0 + side, -direction * 5.0 - side]), COLOR)
	draw_circle(direction * 7.0, 1.8, Color.WHITE)
