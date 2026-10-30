class_name OrbitingKnifeStatus
extends Status
## One of Silt's knives orbiting this unit. Each of the unit's attacks that lands is
## followed by a knife strike. Can also grant Insight Ward.

const ORBIT_RADIUS := 22.0
const ORBIT_SPEED := 4.0   # radians per second
const KNIFE_COLOR := Color(0.85, 0.9, 1.0)

var silt_id: int
var damage: float
var damage_type: int
var wrack_multiplier: float
var time_left: float
var insight_ward_bonus: float
var _knife: Polygon2D
var _angle: float = 0.0


func _init(caster: BattleUnit, p_damage: float, p_wrack_multiplier: float, p_duration: float, p_ward: float) -> void:
	silt_id = caster.get_instance_id()
	damage_type = caster.get_attack_damage_type()
	damage = p_damage
	wrack_multiplier = p_wrack_multiplier
	time_left = p_duration
	insight_ward_bonus = p_ward


func on_applied(unit: BattleUnit) -> void:
	_knife = Polygon2D.new()
	_knife.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(6, 0), Vector2(-3, 2)])
	_knife.color = KNIFE_COLOR
	_knife.z_index = 10
	unit.add_child(_knife)
	_place_knife()


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_knife):
		_knife.queue_free()


func tick(unit: BattleUnit, delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	_place_knife()
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func _place_knife() -> void:
	_knife.position = Vector2.from_angle(_angle) * ORBIT_RADIUS
	_knife.rotation = _angle + PI / 2.0   # point along the orbit


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.INSIGHT_WARD:
		return value + insight_ward_bonus
	return value


func get_hit_effect(_unit: BattleUnit) -> HitEffect:
	return KnifeHitEffect.new(silt_id, damage, damage_type, wrack_multiplier)
