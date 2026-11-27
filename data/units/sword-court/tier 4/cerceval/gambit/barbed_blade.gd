class_name BarbedBlade
extends Projectile
## Cerceval's thrown blade during Barbed Frenzy: flies in a straight line toward where its
## target stood, out to Range Multiple times his attack range, and pierces every enemy on
## the way. The first enemy takes the attack's full damage, each later one Pierce Share of
## it. It's still his attack: every enemy hit gets the attack's wrack and hit effects, and
## counts as an attack hit (so Bloodletter makes it Bleed). Only the first hit gives him attack Charge.
## A: the main blade also throws two smaller side blades fanning out at Side Angle, each
## dealing Side Share of the damage (they pierce too, but give no Charge or hit effects).

const BLADE_SPEED := 520.0   # pixels/sec
## How close to its line an enemy's centre must be to be hit, as a share of a cell: wide
## enough to catch anyone whose hex it crosses near the middle, not the lane beside it.
const HIT_HALF_WIDTH := 0.45
const RANGE_MULTIPLE := 2.0  # how far it flies, as a multiple of his attack range

var direction: Vector2
var remaining: float          # pixels left to travel
var pierce_share := 0.6       # damage after the first enemy
var side_share := 0.0         # A: side blades' damage share (0 = none)
var side_angle := 12.0        # A: degrees either side
var _hits := 0
var _touched := {}
var _gave_charge := false
var _half_width := 25.0   # pixels; set from the board in _aim


func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	super.setup(p_shooter, p_target, p_damage, p_color, p_wrack_level, p_type, p_hit_effects)
	_aim(p_shooter, (p_target.global_position - p_shooter.global_position).normalized())
	if side_share > 0.0:
		for turn_sign in [-1.0, 1.0]:
			var side := BarbedBlade.new()
			side.pierce_share = pierce_share
			side.grants_charge = false
			side.setup(p_shooter, p_target, p_damage * side_share, p_color, p_wrack_level, p_type, [])
			side._aim(p_shooter, direction.rotated(deg_to_rad(side_angle) * turn_sign), 0.7)
			p_shooter.get_tree().current_scene.add_child(side)
			side.global_position = p_shooter.global_position


## Points the blade along `dir` and sizes it (`scale_by` < 1 for the smaller side blades).
func _aim(shooter: BattleUnit, dir: Vector2, scale_by: float = 1.0) -> void:
	direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
	var spacing := shooter.grid.cell_spacing()
	_half_width = spacing * HIT_HALF_WIDTH
	remaining = shooter.attack_range * RANGE_MULTIPLE * spacing + spacing * 0.5
	var l := 12.0 * scale_by
	var w := 4.5 * scale_by
	polygon = PackedVector2Array([Vector2(l, 0), Vector2(-l * 0.2, w), Vector2(-l, 0), Vector2(-l * 0.2, -w)])
	color = CercevalFx.COLOR.lightened(0.3) if wrack_level > 0 else CercevalFx.COLOR
	rotation = direction.angle()


## Replaces Projectile's homing: flies straight on, piercing everyone along the way.
func _physics_process(delta: float) -> void:
	var step := minf(BLADE_SPEED * delta * speed_scale(), remaining)
	var from := global_position
	var to := from + direction * step
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == team or _touched.has(unit.get_instance_id()):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) > _half_width:
			continue
		_touched[unit.get_instance_id()] = true
		_hit_unit(unit)
	global_position = to
	remaining -= step
	if remaining <= 0.0:
		queue_free()


func _hit_unit(enemy: BattleUnit) -> void:
	var amount := damage if _hits == 0 else damage * pierce_share
	_hits += 1
	var shooter := instance_from_id(shooter_id) as BattleUnit
	var dealt := enemy.take_damage(amount, wrack_level, damage_type, ignore_ward, shooter)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	if shooter != null:
		if grants_charge and not _gave_charge and dealt > 0.0:
			shooter.gain_charge_from_attack(dealt, enemy)
			_gave_charge = true
		shooter.notify_attack_hit(enemy, dealt)
		enemy.notify_attacked(shooter, dealt)
	enemy.gain_charge_from_hit(dealt)
	BattleUnit.run_hit_effects(hit_effects, enemy, dealt, wrack_level)
