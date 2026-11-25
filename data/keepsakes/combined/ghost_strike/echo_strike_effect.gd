class_name EchoStrikeEffect
extends Passive
## Ghost Strike: every few attacks, the attack's Hit Effects trigger an additional time
## (see Status.extra_hit_effect_runs). A ghostly echo of the swing shows when it happens.
## Hit Effect: a ghostly bolt flies at the target for Bolt Damage + Bolt Insight Scaling x
## Insight as Insight damage (it never Wracks), so Ghost Strike has a Hit Effect to echo
## even when it's the unit's only one.

@export var every: int = 4
@export var bolt_damage: float = 20.0
@export var bolt_insight_scaling: float = 0.2
## Might Empower: the bolt also scales with Might.
@export var bolt_might_scaling: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Echo.new(every, bolt_damage, bolt_insight_scaling, bolt_might_scaling))


class Echo extends Status:
	var every: int
	var bolt_damage: float
	var bolt_scaling: float
	var bolt_might_scaling: float
	var _count := 0
	var _echo := false   # this attack is the one that echoes

	func _init(p_every: int, p_bolt_damage: float, p_bolt_scaling: float, p_might_scaling: float = 0.0) -> void:
		every = p_every
		bolt_damage = p_bolt_damage
		bolt_scaling = p_bolt_scaling
		bolt_might_scaling = p_might_scaling

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		var damage := Stats.scaled(bolt_damage, bolt_scaling, unit.get_stat(Stats.Stat.INSIGHT))
		damage = Stats.scaled(damage, bolt_might_scaling, unit.get_stat(Stats.Stat.MIGHT))
		return BoltHit.new(unit, damage)

	func on_attack(_unit: BattleUnit) -> void:
		_count += 1
		_echo = _count >= every
		if _echo:
			_count = 0

	func extra_hit_effect_runs(unit: BattleUnit) -> int:
		if not _echo:
			return 0
		_echo = false
		var target = unit.attack_target if is_instance_valid(unit.attack_target) else unit.target   # Beams don't set attack_target
		if is_instance_valid(target):
			KeepsakeVfx.ghost_strike(unit, target)
		return 1


## The Hit Effect: launches a ghostly bolt from the attacker at the target. Its damage is
## fixed when the attack is made.
class BoltHit extends HitEffect:
	var attacker   # untyped: may be freed by the time the attack lands
	var credit_id: int
	var damage: float

	func _init(p_attacker: BattleUnit, p_damage: float) -> void:
		attacker = p_attacker
		credit_id = p_attacker.get_credit_id()
		damage = p_damage

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not target.alive or not target.is_inside_tree():
			return   # the attack already finished it
		var from: Vector2 = attacker.global_position if is_instance_valid(attacker) else target.global_position
		var bolt := GhostBolt.new()
		bolt.target = target
		bolt.credit_id = credit_id
		bolt.damage = damage
		target.get_parent().add_child(bolt)
		bolt.global_position = from


## The bolt in flight: homes in on its target and deals its Insight damage on arrival.
## Fizzles if the target dies first.
class GhostBolt extends Node2D:
	const SPEED := 420.0   # pixels per second
	const RADIUS := 4.0
	var target   # untyped: may be freed
	var credit_id: int
	var damage: float
	var _trail: Array[Vector2] = []

	func _ready() -> void:
		z_index = 6

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive or not target.active:
			queue_free()
			return
		var to: Vector2 = target.global_position
		var step := SPEED * delta
		if SpriteEdge.homing_hit(target, global_position, step) != null:   # stops at the sprite's edge
			var dealt: float = target.take_damage(BattleUnit.damage_bonus(credit_id, target, damage), 0, Stats.DamageType.INSIGHT)
			target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
			queue_free()
			return
		_trail.push_front(global_position)
		if _trail.size() > 6:
			_trail.pop_back()
		global_position = global_position.move_toward(to, step)
		queue_redraw()

	func _draw() -> void:
		var color: Color = KeepsakeVfx.GHOST_TINT
		for i in _trail.size():
			var fade := 1.0 - float(i + 1) / (_trail.size() + 1)
			draw_circle(to_local(_trail[i]), RADIUS * fade, Color(color, 0.45 * fade))
		draw_circle(Vector2.ZERO, RADIUS * 1.8, Color(color, 0.25))
		draw_circle(Vector2.ZERO, RADIUS, Color(1, 1, 1, 0.9))
