class_name ShrapnelForgeEffect
extends Passive
## An Ascension effect (Obelisk, Shrapnel Forge): whenever a unit creates a Shard or Keepsake
## in combat (KeepsakeForge), it fires a hunk of shrapnel per piece (a Shard is 1, a Keepsake
## 2) at the enemy with the most health within Range Cells: Health Share of that enemy's max
## health as Might damage, and a Stun.

@export var health_share: float = 0.1
@export var stun: float = 1.0
@export var range_cells: int = 4

const COLOR := Color(0.75, 0.75, 0.8)


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ForgeStatus.new(self))


## The enemy with the most health within range of `unit`, or null.
func target_for(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == unit.team or not enemy.is_targetable() \
				or unit.grid.get_distance(unit.cell, enemy.cell) > range_cells:
			continue
		if best == null or enemy.health > best.health:
			best = enemy
	return best


func land(unit: BattleUnit, target: BattleUnit) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var source = unit if is_instance_valid(unit) else null
	var dealt := target.take_damage(BattleUnit.damage_bonus(source, target, target.max_health * health_share), 0, Stats.DamageType.MIGHT)
	if source != null:
		source.get_tree().call_group("damage_tracker", "record_damage", source.get_credit_id(), dealt)
	if target.alive:
		target.stun(stun, source)
	KeepsakeVfx.burst(target, COLOR)


class ForgeStatus extends Status:
	var effect: ShrapnelForgeEffect

	func _init(p_effect: ShrapnelForgeEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_keepsake_created(unit: BattleUnit, pieces: int) -> void:
		for i in pieces:
			var target := effect.target_for(unit)
			if target == null:
				return
			var hunk := Hunk.new()
			hunk.effect = effect
			hunk.source = unit
			hunk.target = target
			hunk.delay = 0.12 * i
			unit.get_parent().add_child(hunk)
			hunk.global_position = unit.global_position


## A hunk of metal arcing from its maker to its target; lands on arrival.
class Hunk extends Node2D:
	const SPEED := 420.0
	var effect: ShrapnelForgeEffect
	var source   # untyped: may be freed
	var target   # untyped: may be freed
	var delay := 0.0
	var _start := Vector2.ZERO
	var _t := 0.0
	var _spin := 0.0

	func _ready() -> void:
		_start = global_position

	func _physics_process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			return
		if not is_instance_valid(target) or not target.alive:
			queue_free()
			return
		var length := maxf(_start.distance_to(target.global_position), 1.0)
		_t = minf(_t + SPEED * delta / length, 1.0)
		var flat := _start.lerp(target.global_position, _t)
		global_position = flat + Vector2(0, -sin(_t * PI) * minf(length * 0.3, 60.0))
		_spin += delta * 14.0
		queue_redraw()
		if _t >= 1.0:
			effect.land(source if is_instance_valid(source) else null, target)
			queue_free()

	func _draw() -> void:
		var points := PackedVector2Array()
		for i in 5:
			var a := _spin + TAU * i / 5.0
			points.append(Vector2(cos(a), sin(a)) * (7.0 if i % 2 == 0 else 4.0))
		draw_colored_polygon(points, ShrapnelForgeEffect.COLOR)
		points.append(points[0])
		draw_polyline(points, Color(0.3, 0.3, 0.35), 1.5)
