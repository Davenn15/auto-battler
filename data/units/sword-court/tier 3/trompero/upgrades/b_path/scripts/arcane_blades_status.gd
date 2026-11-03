class_name ArcaneBladesStatus
extends Status
## Arcane blades orbiting the unit for the rest of combat. Each time the unit attacks,
## every blade fires its own Insight shot at the same target.

const ORBIT_RADIUS := 26.0
const ORBIT_SPEED := 3.0   # radians per second
const BLADE_COLOR := Color(0.708, 0.094, 0.297)   # the same violet as the ring

var damage: float
var insight_scaling: float
var charge_per_hit: float   # charge each landed blade shot gives the unit. 0 = none
var _blades: Array[Polygon2D] = []
var _angle: float = 0.0


func _init(p_damage: float, p_insight_scaling: float, p_charge_per_hit: float) -> void:
	damage = p_damage
	insight_scaling = p_insight_scaling
	charge_per_hit = p_charge_per_hit


## Statuses a Gambit creates block charge until they end. These never end, so they mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func add_blades(unit: BattleUnit, count: int) -> void:
	for i in count:
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([Vector2(-4, -2), Vector2(8, 0), Vector2(-4, 2)])
		blade.color = BLADE_COLOR
		blade.z_index = 10
		unit.add_child(blade)
		_blades.append(blade)
	_place_blades()


func blade_count() -> int:
	return _blades.size()


func on_removed(_unit: BattleUnit) -> void:
	for blade in _blades:
		if is_instance_valid(blade):
			blade.queue_free()
	_blades.clear()


func tick(_unit: BattleUnit, delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	_place_blades()


## Spreads the blades evenly around the unit.
func _place_blades() -> void:
	for i in _blades.size():
		var a := _angle + TAU * i / _blades.size()
		_blades[i].position = Vector2.from_angle(a) * ORBIT_RADIUS
		_blades[i].rotation = a + PI / 2.0   # point along the orbit


func on_attack(unit: BattleUnit) -> void:
	var target := unit.target
	if not unit._is_valid_target(target):
		return
	var amount := Stats.scaled(damage, insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))
	var effects: Array[HitEffect] = []
	if charge_per_hit > 0.0:
		effects.append(ChargeHitEffect.new(unit.get_instance_id(), charge_per_hit))
	for blade in _blades:
		var shot := Projectile.new()
		shot.setup(unit, target, amount, BLADE_COLOR, 0, Stats.DamageType.INSIGHT, effects)
		shot.grants_charge = false
		unit.get_tree().current_scene.add_child(shot)
		shot.global_position = blade.global_position   # fired from where the blade is
