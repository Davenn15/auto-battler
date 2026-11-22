class_name PierceBolt
extends Projectile
## A large bolt that flies in a straight line and damages each enemy it passes through,
## once per enemy. Damage is computed per enemy as: flat_damage + percent of their max health.
## Everything it needs is copied in at fire time, so it keeps flying if the shooter dies.
## It's a projectile: an enemy area that slows shots slows it, and an enemy that sends
## projectiles back (Glaive's spin, a parry, Balmede's plant) turns it around. It then
## belongs to that enemy and flies its full reach back, piercing Crommel's side instead.

var direction: Vector2
var reach: float              # how far it flies, also after being sent back
var remaining: float          # distance left to travel
var hit_radius: float
var flat_damage: float
var percent_max_health: float
var wrack_multiplier: float = 1.0    # damage multiplier on a wrackack
var _hit_ids: Dictionary = {}   # instance ids of enemies already hit
var _reflected := false   # sent back: its damage is no longer the shooter's Gambit damage


func setup_bolt(p_shooter_id: int, p_team: int, p_direction: Vector2, p_reach: float,
		p_radius: float, p_flat_damage: float, p_percent: float, p_type: int,
		p_wrack_level: int = 0, p_wrack_multiplier: float = 1.0) -> void:
	shooter_id = p_shooter_id
	credit_id = p_shooter_id
	team = p_team
	direction = p_direction
	reach = p_reach
	remaining = p_reach
	is_attack = false
	grants_charge = false
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


func _physics_process(delta: float) -> void:
	var step := minf(speed * delta * speed_scale(), remaining)
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
			if unit.try_reflect(self):
				global_position = closest   # turns around where it was sent back
				return
			_strike(unit)

	global_position = to
	remaining -= step
	if remaining <= 0.0:
		queue_free()


func _strike(unit: BattleUnit) -> void:
	var amount := (flat_damage + percent_max_health * unit.max_health) * pow(wrack_multiplier, wrack_level)
	var dealt := unit.take_damage(BattleUnit.damage_bonus(shooter_id, unit, amount), wrack_level, damage_type)
	if not _reflected:
		BattleUnit.gambit_damage_dealt(shooter_id, unit, dealt)   # Gambit damage (see BattleUnit)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)


## Sent back by `by`: turns around (or heads straight for `to`, when given: Wesper B1),
## now on `by`'s side, and flies its full reach again, able to hit everyone on the other
## side (the reflector itself excepted). It rolls for wrack again at `wrack_chance`; a
## higher roll uses `by`'s Wrack Damage.
func reflect(by: BattleUnit, wrack_chance: float, to: BattleUnit = null) -> bool:
	var rolled := Stats.roll_wrack(wrack_chance)
	if rolled > wrack_level:
		wrack_level = rolled
		wrack_multiplier = Stats.wrack_multiplier(1, by.get_stat(Stats.Stat.WRACK_DAMAGE))
	shooter_id = by.get_instance_id()
	credit_id = by.get_credit_id()
	team = by.team
	var aim := (to.global_position - global_position).normalized() if is_instance_valid(to) and to.alive and to.team != by.team else Vector2.ZERO
	direction = aim if aim != Vector2.ZERO else -direction
	rotation = direction.angle()
	remaining = reach
	_hit_ids = {by.get_instance_id(): true}
	_reflected = true
	color = BattleUnit.team_color(by.team)
	return true
