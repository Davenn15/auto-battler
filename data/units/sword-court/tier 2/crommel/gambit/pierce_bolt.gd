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
var wrack_level: int = 0           # rolled once at fire time; applies to every enemy hit
var wrack_multiplier: float = 1.0    # damage multiplier on a wrackack
var _hit_ids: Dictionary = {}   # instance ids of enemies already hit


func setup(p_shooter_id: int, p_team: int, p_direction: Vector2, p_reach: float,
		p_radius: float, p_flat_damage: float, p_percent: float, p_type: int,
		p_wrack_level: int = 0, p_wrack_multiplier: float = 1.0) -> void:
	shooter_id = p_shooter_id
	team = p_team
	direction = p_direction
	remaining = p_reach
	hit_radius = p_radius
	flat_damage = p_flat_damage
	percent_max_health = p_percent
	damage_type = p_type
	wrack_level = p_wrack_level
	wrack_multiplier = p_wrack_multiplier

	# Visual: a long thin bolt pointing along its direction of travel.
	var half_width := hit_radius / 4.5   # 4 pixels at the default radius of 18
	polygon = PackedVector2Array([Vector2(-22, -half_width), Vector2(22, -half_width),
		Vector2(22, half_width), Vector2(-22, half_width)])
	color = Color(0.456, 0.281, 0.543, 1.0)
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
	var amount := (flat_damage + percent_max_health * unit.max_health) * pow(wrack_multiplier, wrack_level)
	var dealt := unit.take_damage(amount, wrack_level, damage_type)
	get_tree().call_group("damage_tracker", "record_damage", shooter_id, dealt)
