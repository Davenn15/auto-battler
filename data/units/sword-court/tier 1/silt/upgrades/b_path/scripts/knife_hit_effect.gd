class_name KnifeHitEffect
extends HitEffect
## Hit Effect: once the attack lands, one of Silt's knives flies from the attacker to the
## target and strikes it on arrival. It wracks whenever the attack it follows wracked.

const SPEED := 420.0        # pixels per second
const MIN_FLIGHT := 0.1     # seconds, so even an adjacent throw is visible
const MAX_FLIGHT := 0.35

var silt_id: int
var damage: float
var damage_type: int
var wrack_multiplier: float
var attacker   # untyped: may be freed before the knife is thrown
var _from := Vector2.ZERO
var _thrown := false   # with a thrower, a knife visibly flies; without one it strikes at once


func _init(p_silt_id: int, p_damage: float, p_type: int, p_wrack_multiplier: float, p_attacker: BattleUnit = null) -> void:
	silt_id = p_silt_id
	damage = p_damage
	damage_type = p_type
	wrack_multiplier = p_wrack_multiplier
	attacker = p_attacker
	_thrown = p_attacker != null
	if _thrown:
		_from = p_attacker.global_position


func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
	if not target.alive:
		return   # the attack already finished it
	if not _thrown:
		strike(target, wrack_level)   # no thrower (Vere's bonus strikes): it lands at once
		return
	var knife := FlyingKnife.new()
	knife.effect = self
	knife.target = target
	knife.wrack_level = wrack_level
	knife.z_index = 12
	target.get_parent().add_child(knife)
	var start: Vector2 = attacker.global_position if is_instance_valid(attacker) else _from
	knife.launch(start + Vector2(0, -8))


## The knife arrived: the strike itself.
func strike(target: BattleUnit, wrack_level: int) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var amount := damage * pow(wrack_multiplier, wrack_level)
	var dealt := target.take_damage(amount, wrack_level, damage_type)
	target.get_tree().call_group("damage_tracker", "record_damage", silt_id, dealt)


## The thrown knife: flies straight at the target (following it if it moves), spinning
## once on the way, then strikes. Its own node, so it lands even if the thrower dies.
class FlyingKnife extends Node2D:
	var effect: KnifeHitEffect
	var target   # untyped: may be freed
	var wrack_level := 0
	var _start := Vector2.ZERO
	var _t := 0.0
	var _flight := 0.2

	func launch(from: Vector2) -> void:
		_start = from
		global_position = from
		var goal: Vector2 = target.global_position + Vector2(0, -8)
		_flight = clampf(from.distance_to(goal) / KnifeHitEffect.SPEED, KnifeHitEffect.MIN_FLIGHT, KnifeHitEffect.MAX_FLIGHT)
		rotation = (goal - from).angle()

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			queue_free()   # nothing left to hit
			return
		_t = minf(_t + delta / _flight, 1.0)
		var goal: Vector2 = target.global_position + Vector2(0, -8)
		global_position = _start.lerp(goal, _t)
		rotation = (goal - _start).angle()
		if _t >= 1.0:
			effect.strike(target, wrack_level)
			queue_free()

	func _process(_delta: float) -> void:
		queue_redraw()

	## The same knife that orbits the unit, a touch bigger, with a faint trail behind it.
	func _draw() -> void:
		var color := OrbitingKnifeStatus.KNIFE_COLOR
		draw_line(Vector2(-14, 0), Vector2(-3, 0), Color(color, 0.35), 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -2.5), Vector2(8, 0), Vector2(-4, 2.5)]), color)
		draw_line(Vector2(-4, -3), Vector2(-4, 3), Color(0.35, 0.3, 0.3), 1.5)
