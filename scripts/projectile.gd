class_name Projectile
extends Polygon2D
## A square that homes in on its target and deals damage when it arrives.
## It is independent of its shooter, so it keeps flying even if the shooter dies.

const SPEED := 600.0       # pixels/sec
const SIZE := 5.0          # half the square's width
const HIT_DISTANCE := 6.0  # close enough to count as a hit

var shooter_id: int   # a number, so it stays valid even after the shooter is freed
var target: BattleUnit
var damage: float
var damage_type: int = 0
var is_wrack: bool = false
var hit_effects: Array[HitEffect] = []
var credit_id: int    # who the damage meter credits; the summoner for summons


func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack: bool = false, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	hit_effects = p_hit_effects
	is_wrack = p_wrack
	shooter_id = p_shooter.get_instance_id()
	credit_id = p_shooter.get_credit_id()
	target = p_target
	damage = p_damage
	damage_type = p_type
	polygon = PackedVector2Array([
		Vector2(-SIZE, -SIZE), Vector2(SIZE, -SIZE),
		Vector2(SIZE, SIZE), Vector2(-SIZE, SIZE)])
	color = p_color
	z_index = 10

func _process(delta: float) -> void:
	# Target died or was freed while we were in the air: the shot fizzles.
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return

	var to_target := target.global_position - global_position
	var step := SPEED * delta
	if to_target.length() <= maxf(step, HIT_DISTANCE):
		_hit()
	else:
		global_position += to_target.normalized() * step


func _hit() -> void:
	var dealt := target.take_damage(damage, is_wrack, damage_type)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	var shooter := instance_from_id(shooter_id) as BattleUnit
	if shooter != null:
		shooter.gain_charge_from_attack(dealt)
		shooter.notify_attack_hit(target, dealt)
	target.gain_charge_from_hit(dealt)
	BattleUnit.run_hit_effects(hit_effects, target, dealt, is_wrack)
	queue_free()
