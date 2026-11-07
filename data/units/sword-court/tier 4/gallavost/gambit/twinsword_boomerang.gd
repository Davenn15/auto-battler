class_name TwinswordBoomerang
extends Polygon2D
## Gallavost's thrown twinsword. Flies out in a straight line, then comes back to the
## thrower, hitting and stunning every enemy it passes on each leg. When it's caught, the
## thrower gains a shield. Everything it needs is copied in, so it still comes back
## (to where the thrower last stood) if the thrower dies.

const SPEED := 500.0   # pixels/sec

var thrower_id: int
var team: int
var direction: Vector2
var reach: float         # pixels it flies out
var hit_radius: float
var damage: float
var damage_type: int
var ignore_ward: bool
var stun_time: float
var wrack_level: int = 0   # rolled when thrown; applies to every hit
var catch_shield: float
var catch_shield_duration: float
var size: float = 1.0    # how big it's drawn (1 = normal); the hit width is set separately
var _travelled := 0.0
var _returning := false
var _home: Vector2       # where it's flying back to
var _hit_ids := {}       # enemies hit on this leg
var ally_shield: float = 0.0
var ally_shield_duration: float = 4.0

func _ready() -> void:
	# A double-ended blade: two points joined at a narrow grip.
	polygon = PackedVector2Array([Vector2(-26, 0), Vector2(-6, -5), Vector2(0, -2), Vector2(6, -5),
			Vector2(26, 0), Vector2(6, 5), Vector2(0, 2), Vector2(-6, 5)])
	color = Color(1.0, 0.95, 0.7)   # bright, pure gold
	scale = Vector2.ONE * size
	z_index = 10


func _physics_process(delta: float) -> void:
	rotation += 20.0 * delta   # spins as it flies
	var thrower := instance_from_id(thrower_id) as BattleUnit
	if thrower != null and thrower.alive:
		_home = thrower.global_position
	var from := global_position
	var to: Vector2
	if not _returning:
		var step := minf(SPEED * delta, reach - _travelled)
		to = from + direction * step
		_travelled += step
	else:
		to = from.move_toward(_home, SPEED * delta)
	_hit_along(from, to)
	global_position = to
	if not _returning and _travelled >= reach:
		_returning = true
		_hit_ids.clear()   # it can hit everyone again on the way back
	elif _returning and global_position.distance_to(_home) < 1.0:
		_caught(thrower)


func _hit_along(from: Vector2, to: Vector2) -> void:
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or _hit_ids.has(unit.get_instance_id()):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) > hit_radius:
			continue
		if unit.team == team:
			if ally_shield > 0.0 and unit.get_instance_id() != thrower_id:
				_hit_ids[unit.get_instance_id()] = true
				unit.add_shield(ally_shield, ally_shield_duration, thrower_id)
			continue
		_hit_ids[unit.get_instance_id()] = true
		var dealt := unit.take_damage(damage, wrack_level, damage_type, ignore_ward)
		get_tree().call_group("damage_tracker", "record_damage", thrower_id, dealt)
		if dealt > 0.0 and unit.alive:
			unit.stun(stun_time, instance_from_id(thrower_id) as BattleUnit)


func _caught(thrower: BattleUnit) -> void:
	if thrower != null and thrower.alive:
		thrower.add_shield(catch_shield, catch_shield_duration, thrower_id)
	queue_free()
