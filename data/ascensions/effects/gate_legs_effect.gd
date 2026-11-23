class_name GateLegsEffect
extends Passive
## GATE.W(A)'s hero Ascension: it sprouts legs. It walks like a normal unit and attacks with
## Attack Range, and each attack opens a small portal above its target and drops a hunk of
## metal on it: the attack's normal damage, plus a Hit Effect dealing Max Health Share of
## the target's max health and stunning it for Stun seconds. It keeps its passive's Charge
## Regen. GatePassive checks for the marker (has_on) to let it move and attack.

@export var attack_range: int = 3
@export var max_health_share: float = 0.07
@export var stun: float = 0.5

const PORTAL := Color(0.75, 0.45, 1.0)
const METAL := Color(0.55, 0.57, 0.62)


func on_battle_start(unit: BattleUnit) -> void:
	unit.attack_range = attack_range
	var status := LegsStatus.new()
	status.effect = self
	unit.add_status(status)


## True if `unit` has the Ascension (GatePassive then lets it walk and attack).
static func has_on(unit: BattleUnit) -> bool:
	for status in unit.statuses:
		if status is LegsStatus:
			return true
	return false


class LegsStatus extends Status:
	var effect: GateLegsEffect
	var _look: LegsLook

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		if KeepsakeVfx.enabled():
			_look = LegsLook.new()
			_look.unit = unit
			_look.z_index = -1   # under its sprite
			unit.add_child(_look)

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_look):
			_look.queue_free()

	func create_projectile(_unit: BattleUnit) -> Projectile:
		return MetalDrop.new()

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return DropHit.new(unit.get_credit_id(), unit.get_instance_id(), effect.max_health_share, effect.stun, unit.get_attack_damage_type())


## The metal's extra: max-health damage and a short stun.
class DropHit extends HitEffect:
	var credit_id: int
	var source_id: int
	var share: float
	var stun: float
	var damage_type: int

	func _init(p_credit_id: int, p_source_id: int, p_share: float, p_stun: float, p_type: int) -> void:
		credit_id = p_credit_id
		source_id = p_source_id
		share = p_share
		stun = p_stun
		damage_type = p_type

	func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
		if not target.alive:
			return
		var amount := BattleUnit.damage_bonus(credit_id, target, target.max_health * share)
		var dealt := target.take_damage(amount, wrack_level, damage_type)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
		if target.alive:
			var source := instance_from_id(source_id) as BattleUnit if is_instance_id_valid(source_id) else null
			target.stun(stun, source)


## The attack's shot: it starts above the target (out of a portal) and falls onto it.
class MetalDrop extends Projectile:
	const DROP_HEIGHT := 70.0
	var _placed := false

	func _physics_process(delta: float) -> void:
		if not _placed:
			_placed = true
			if is_instance_valid(target):
				global_position = target.global_position + Vector2(0, -DROP_HEIGHT)
				var portal := Portal.new()
				get_parent().add_child(portal)
				portal.global_position = global_position + Vector2(0, -6)
			polygon = PackedVector2Array([Vector2(-7, -5), Vector2(6, -6), Vector2(8, 4), Vector2(-5, 6)])
			color = GateLegsEffect.METAL
			speed = 320.0
		super(delta)
		rotation += delta * 6.0

	func _draw() -> void:
		draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color(0.3, 0.31, 0.35), 1.5)


## The small portal the metal drops out of: opens, holds, closes.
class Portal extends Node2D:
	const LIFE := 0.5
	var _time := 0.0

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		_time += delta
		if _time >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var open := clampf(_time / 0.12, 0.0, 1.0) * clampf((LIFE - _time) / 0.15, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 14.0 * open, Color(0.15, 0.05, 0.25, 0.85))
		draw_arc(Vector2.ZERO, 14.0 * open, 0.0, TAU, 28, Color(GateLegsEffect.PORTAL, 0.95), 2.5, true)
		draw_set_transform(Vector2.ZERO)


## Placeholder legs (drawn in code, no art yet): four thin mechanical legs under it that
## step while it walks.
class LegsLook extends Node2D:
	var unit: BattleUnit
	var _time := 0.0
	var _last := Vector2.ZERO

	func _process(delta: float) -> void:
		if is_instance_valid(unit):
			var moved := unit.global_position.distance_to(_last) > 0.1
			_last = unit.global_position
			if moved:
				_time += delta
		queue_redraw()

	func _draw() -> void:
		var size := KeepsakeVfx._sprite_size(unit) if is_instance_valid(unit) else Vector2(48, 48)
		var hip_y := size.y * 0.2
		var foot_y := size.y * 0.5 + 6.0
		for i in 4:
			var side := -1.0 if i < 2 else 1.0
			var spread := 0.35 if i % 2 == 0 else 0.6
			var lift := maxf(0.0, sin(_time * 12.0 + i * PI * 0.5)) * 4.0
			var hip := Vector2(side * size.x * 0.2, hip_y)
			var knee := Vector2(side * size.x * (spread + 0.1), hip_y - 4.0 - lift)
			var foot := Vector2(side * size.x * spread, foot_y - lift)
			draw_line(hip, knee, Color(0.22, 0.23, 0.27), 3.0)
			draw_line(knee, foot, Color(0.3, 0.31, 0.36), 2.0)
			draw_circle(knee, 2.0, GateLegsEffect.PORTAL)
