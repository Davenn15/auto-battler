class_name EnergyWave
extends Projectile
## Geomond's Tectonic attack: a wide wave that rolls in a straight line toward where its
## target stood, out to his attack range, hitting every enemy it passes once. It's still
## his attack: each enemy hit gets the attack's damage, wrack, and hit effects. It can also
## shield allies it passes. Waves can't be reflected.

const WAVE_SPEED := 450.0   # pixels/sec
const WAVE_COLOR := Color(1.0, 0.55, 0.15)

var team: int
var direction: Vector2
var remaining: float          # pixels left to travel
var half_width: float = 20.0  # set before setup
var ally_shield: float = 0.0
var ally_shield_duration: float = 3.0
var _touched: Dictionary = {}   # instance ids already hit or shielded
var _gave_charge: bool = false
var max_health_percent: float = 0.0   # extra damage per enemy, as a share of its max health
var wrack_multiplier: float = 1.0     # applied to that extra damage when the attack wracked

func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	super.setup(p_shooter, p_target, p_damage, p_color, p_wrack_level, p_type, p_hit_effects)
	team = p_shooter.team
	direction = (p_target.global_position - p_shooter.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var spacing := p_shooter.grid.cell_spacing()
	remaining = p_shooter.attack_range * spacing + spacing * 0.5
	polygon = PackedVector2Array([Vector2(-4, -half_width), Vector2(4, -half_width),
			Vector2(4, half_width), Vector2(-4, half_width)])
	color = WAVE_COLOR.lightened(0.45) if wrack_level > 0 else WAVE_COLOR
	rotation = direction.angle()


## Replaces Projectile's homing: rolls straight on, touching everyone along the way.
func _physics_process(delta: float) -> void:
	var step := minf(WAVE_SPEED * delta, remaining)
	var from := global_position
	var to := from + direction * step
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or _touched.has(unit.get_instance_id()):
			continue
		# Distance to the segment travelled this frame, so the wave can't skip past anyone.
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) > half_width:
			continue
		if unit.team != team:
			_touched[unit.get_instance_id()] = true
			_hit_unit(unit)
		elif ally_shield > 0.0 and unit.get_instance_id() != shooter_id:
			_touched[unit.get_instance_id()] = true
			unit.add_shield(ally_shield, ally_shield_duration, credit_id)
	global_position = to
	remaining -= step
	if remaining <= 0.0:
		queue_free()


## One enemy hit. The attacker's charge comes from the first enemy the wave damages only;
## everything else happens for each enemy.
func _hit_unit(enemy: BattleUnit) -> void:
	var extra := max_health_percent * enemy.max_health * pow(wrack_multiplier, wrack_level)
	var dealt := enemy.take_damage(damage + extra, wrack_level, damage_type, ignore_ward, instance_from_id(shooter_id) as BattleUnit)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	var shooter := instance_from_id(shooter_id) as BattleUnit
	if shooter != null:
		if not _gave_charge and dealt > 0.0:
			shooter.gain_charge_from_attack(dealt, enemy)
			_gave_charge = true
		enemy.notify_attacked(shooter, dealt)
		shooter.notify_attack_hit(enemy, dealt)
	enemy.gain_charge_from_hit(dealt)
	BattleUnit.run_hit_effects(hit_effects, enemy, dealt, wrack_level)
