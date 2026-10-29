class_name PierceBolt
extends Polygon2D
## A large bolt that flies in a straight line and damages each enemy it passes through,
## once per enemy. Damage is computed per enemy as: flat_damage + percent of their max health.
## Everything it needs is copied in at fire time, so it keeps flying if the shooter dies.

const SPEED := 600.0   # pixels/sec

var shooter_id: int
var team: int
var direction: Vector2
var remaining: float          # distance left to travel
var hit_radius: float
var flat_damage: float
var percent_max_health: float
var damage_type: int
var _hit_ids: Dictionary = {}   # instance ids of enemies already hit


func setup(p_shooter_id: int, p_team: int, p_direction: Vector2, p_reach: float,
		p_radius: float, p_flat_damage: float, p_percent: float, p_type: int) -> void:
	shooter_id = p_shooter_id
	team = p_team
	direction = p_direction
	remaining = p_reach
	hit_radius = p_radius
	flat_damage = p_flat_damage
	percent_max_health = p_percent
	damage_type = p_type

	# Visual: a long thin bolt pointing along its direction of travel.
	polygon = PackedVector2Array([Vector2(-22, -4), Vector2(22, -4), Vector2(22, 4), Vector2(-22, 4)])
	color = Color(0.85, 0.75, 0.5)
	rotation = direction.angle()
	z_index = 10


func _process(delta: float) -> void:
	var step := minf(SPEED * delta, remaining)
	var from := global_position
	var to := from + direction * step

	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == team:
			continue
		if _hit_ids.has(unit.get_instance_id()):
			continue
		# Distance to the segment travelled this frame, so a fast bolt can't skip past anyone.
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) <= hit_radius:
			_hit_ids[unit.get_instance_id()] = true
			_hit(unit)

	global_position = to
	remaining -= step
	if remaining <= 0.0:
		queue_free()


func _hit(unit: BattleUnit) -> void:
	var amount := flat_damage + percent_max_health * unit.max_health
	var dealt := unit.take_damage(amount, false, damage_type)   # Gambit damage doesn't wrack
	get_tree().call_group("damage_tracker", "record_damage", shooter_id, dealt)
