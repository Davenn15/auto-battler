class_name LavaPool
extends Polygon2D
## A strip of lava left by Geomond's slam, the same shape as the slam. It burns enemies
## standing in it every half second, then fades. Everything it needs is copied in when
## it's made, so it keeps burning even if Geomond dies.

const TICK_INTERVAL := 0.5
const LAVA_COLOR := Color(1.0, 0.35, 0.05)

var caster_id: int
var team: int
var origin: Vector2
var dir: Vector2
var length: float
var half_width: float
var damage_per_second: float
var damage_type: int
var _time_left: float
var _tick_timer: float = TICK_INTERVAL


func setup(caster: BattleUnit, p_origin: Vector2, p_dir: Vector2, p_length: float,
		p_half_width: float, p_damage_per_second: float, p_duration: float, p_type: int) -> void:
	caster_id = caster.get_instance_id()
	team = caster.team
	origin = p_origin
	dir = p_dir
	length = p_length
	half_width = p_half_width
	damage_per_second = p_damage_per_second
	_time_left = p_duration
	damage_type = p_type
	polygon = PackedVector2Array([Vector2(0, -half_width), Vector2(length, -half_width),
			Vector2(length, half_width), Vector2(0, half_width)])
	color = Color(LAVA_COLOR, 0.35)
	rotation = dir.angle()
	z_index = -1   # under the units


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += TICK_INTERVAL
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or not unit.active or unit.team == team:
				continue
			if SlamGambit.in_rectangle(unit.global_position, origin, dir, length, half_width):
				var dealt := unit.take_damage(damage_per_second * TICK_INTERVAL, 0, damage_type, false, null, false)
				unit.add_running_damage("lava_%d" % get_instance_id(), dealt, Stats.damage_color(damage_type), 0, TICK_INTERVAL + 0.25)
				get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
	if _time_left <= 0.0:
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
