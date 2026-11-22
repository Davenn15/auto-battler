class_name Projectile
extends Polygon2D
## A shot that homes in on its target and deals damage when it arrives.
## It is independent of its shooter, so it keeps flying even if the shooter dies.
## Plain shots look like a small comet: a head in the shot's colour with a white core and a
## tapering tail. Shots that set their own polygon (Crommel's bolt, Von Carrow's bullet,
## Prancelot's notes...) replace the head, and the tail and core go away with it.

const SPEED := 600.0       # pixels/sec
const SIZE := 5.0          # half the old square's width (kept for anything that reads it)
const HIT_DISTANCE := 6.0  # close enough to count as a hit

const COMET_RADIUS := 3.5        # the head
const COMET_CORE_RADIUS := 1.6   # the white centre
const COMET_CORE_SHIFT := 0.8    # the core sits a little toward the front
const COMET_TAIL_LENGTH := 18.0
const COMET_TAIL_WIDTH := 3.0    # half-width where the tail meets the head
const COMET_TAIL_ALPHA := 0.55
const COMET_SIDES := 10
static var _comet_head := PackedVector2Array()

var _heading := Vector2.RIGHT   # the way it's flying, on screen
var _core: Polygon2D

var shooter_id: int   # a number, so it stays valid even after the shooter is freed
var target: BattleUnit
var damage: float
var damage_type: int = 0
var wrack_level: int = 0
var hit_effects: Array[HitEffect] = []
var credit_id: int    # who the damage meter credits; the summoner for summons
var ignore_ward: bool = false   # the hit skips the target's wards
var grants_charge: bool = true   # false for extra shots that shouldn't build attack charge
var is_attack: bool = true   # false for shots that aren't attacks (no charge, no on-hit, no retaliation)
var team: int = 0   # the shooter's team, so areas like BUBL(R)'s Warding bubble can slow enemy shots
var speed: float = SPEED   # pixels/sec at full speed (Prancelot's notes are slower)

func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	hit_effects = p_hit_effects
	wrack_level = p_wrack_level
	shooter_id = p_shooter.get_instance_id()
	credit_id = p_shooter.get_credit_id()
	team = p_shooter.team
	target = p_target
	damage = p_damage
	damage_type = p_type
	polygon = comet_head()
	color = p_color
	z_index = 10
	_heading = (p_target.global_position - p_shooter.global_position).normalized()
	if _heading == Vector2.ZERO:
		_heading = Vector2.RIGHT
	if _core == null:
		_core = Polygon2D.new()
		_core.color = Color.WHITE
		add_child(_core)
	_core.polygon = _circle(COMET_CORE_RADIUS, 8)


## The plain shot's head: a small circle (shared by every plain shot).
static func comet_head() -> PackedVector2Array:
	if _comet_head.is_empty():
		_comet_head = _circle(COMET_RADIUS, COMET_SIDES)
	return _comet_head

static func _circle(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(Vector2.from_angle(TAU * i / sides) * radius)
	return points

## True while this shot still wears the plain comet look (no custom polygon set).
func _is_comet() -> bool:
	return not polygon.is_empty() and polygon == _comet_head

## Runs alongside any subclass's own _ready, so a shot that swapped its look in setup
## (Prancelot's notes) never shows the core, not even for its first frame.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_update_comet()

## Keeps the tail behind the head and the core toward the front, whichever way it flies
## (and however the shot or the battle view is turned).
func _update_comet() -> void:
	var comet := _is_comet()
	if _core != null:
		_core.visible = comet
		if comet:
			_core.position = _local_heading() * COMET_CORE_SHIFT
	if comet:
		queue_redraw()

func _local_heading() -> Vector2:
	return _heading.rotated(-global_rotation)

func _draw() -> void:
	if not _is_comet():
		return
	var back := -_local_heading()
	var side := back.orthogonal() * COMET_TAIL_WIDTH
	draw_colored_polygon(PackedVector2Array([side, back * COMET_TAIL_LENGTH, -side]),
		Color(color, color.a * COMET_TAIL_ALPHA))

func _physics_process(delta: float) -> void:
	# Target died or was freed while we were in the air: the shot fizzles.
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return

	var to_target := target.global_position - global_position
	var step := speed * delta * speed_scale()
	# It hits the first solid pixel of the target's sprite on the way (SpriteEdge), or the
	# target's centre if the sprite can't be tested.
	var hit_at: Variant = SpriteEdge.homing_hit(target, global_position, step, HIT_DISTANCE)
	if hit_at != null:
		global_position = hit_at
		_hit()
	else:
		_heading = to_target.normalized()
		global_position += _heading * step
	_update_comet()


func _hit() -> void:
	if target.try_reflect(self):
		return   # it's now flying back at whoever fired it
	var dealt := target.take_damage(damage, wrack_level, damage_type, ignore_ward, instance_from_id(shooter_id) as BattleUnit)
	get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	if is_attack:
		var shooter := instance_from_id(shooter_id) as BattleUnit
		if shooter != null:
			if grants_charge:
				shooter.gain_charge_from_attack(dealt, target)
			shooter.notify_attack_hit(target, dealt)
			target.notify_attacked(shooter, dealt)
		target.gain_charge_from_hit(dealt)
		BattleUnit.run_hit_effects(hit_effects, target, dealt, wrack_level)
	_after_hit()
	

## How fast this shot moves right now (1 = full speed): slowed while it's inside an enemy
## area that slows shots, such as BUBL(R)'s Warding bubble (nodes in the "projectile_slowers" group).
func speed_scale() -> float:
	return Projectile.slow_at(self, global_position, team)


## The speed factor for any shot from `team` at `point` (1 = full speed), for shots that
## aren't Projectiles but should be slowed the same way (SEG.FAULT's ion bolts and orb).
## `node` is any node in the scene tree.
static func slow_at(node: Node, point: Vector2, team: int) -> float:
	var factor := 1.0
	for slower in node.get_tree().get_nodes_in_group("projectile_slowers"):
		factor = minf(factor, slower.slow_factor(point, team))
	return factor


## What happens once the shot has hit. Shots that do more, like bouncing, override this.
func _after_hit() -> void:
	queue_free()

## Sends this shot back at whoever fired it (or at `to`, when given: Wesper B1 fires
## deflected shots at her own target), now belonging to `by`. Its damage stays the same,
## but it rolls for wrack again at `wrack_chance` and drops the shooter's on-hit effects.
## Returns false if there's nobody to send it at.
func reflect(by: BattleUnit, wrack_chance: float, to: BattleUnit = null) -> bool:
	var shooter := instance_from_id(shooter_id) as BattleUnit
	if is_instance_valid(to) and to.alive and to.team != by.team:
		shooter = to
	if shooter == null or not shooter.alive:
		return false
	var rolled := Stats.roll_wrack(wrack_chance)
	if rolled > wrack_level:   # only the extra levels add damage
		damage *= Stats.wrack_multiplier(rolled - wrack_level, by.get_stat(Stats.Stat.WRACK_DAMAGE))
		wrack_level = rolled
	shooter_id = by.get_instance_id()
	credit_id = by.get_credit_id()
	target = shooter
	team = by.team
	hit_effects = []
	color = BattleUnit.team_color(by.team)
	return true
