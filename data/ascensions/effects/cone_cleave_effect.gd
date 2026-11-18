class_name ConeCleaveEffect
extends Passive
## An Ascension effect (Lord's Reach): the unit's attacks (Gambit attacks included) gain
## the Hit Effect: every other enemy in a cone past the target, up to Reach cells beyond
## it and Angle degrees wide, takes Share of the damage the target took.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5
@export var reach: int = 2
@export_range(10.0, 180.0, 5.0) var angle: float = 60.0

## The cone's crimson.
const CONE_COLOR := Color(0.75, 0.05, 0.12)


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ConeStatus.new(self))


class ConeStatus extends Status:
	var effect: ConeCleaveEffect

	func _init(p_effect: ConeCleaveEffect) -> void:
		effect = p_effect

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return ConeHit.new(unit, effect)


class ConeHit extends HitEffect:
	var attacker   # untyped: may be freed before the hit lands
	var effect: ConeCleaveEffect
	var _from: Vector2

	func _init(p_attacker: BattleUnit, p_effect: ConeCleaveEffect) -> void:
		attacker = p_attacker
		effect = p_effect
		_from = p_attacker.global_position

	func apply(target: BattleUnit, dealt: float, wrack_level: int) -> void:
		if dealt <= 0.0 or not is_instance_valid(target):
			return
		var from: Vector2 = attacker.global_position if is_instance_valid(attacker) else _from
		var aim := target.global_position - from
		if aim.length_squared() < 1.0:
			return
		aim = aim.normalized()
		var half := deg_to_rad(effect.angle / 2.0 + 2.0)   # a little slack for the hex grid
		var by: BattleUnit = attacker if is_instance_valid(attacker) and attacker.alive else null
		var credit: int = attacker.get_credit_id() if is_instance_valid(attacker) else 0
		for node in target.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other == null or other == target or not other.alive or other.team != target.team \
					or target.grid.get_distance(target.cell, other.cell) > effect.reach:
				continue
			var offset := other.global_position - target.global_position
			if offset.length_squared() < 1.0 or absf(aim.angle_to(offset)) > half:
				continue
			var amount := dealt * effect.share   # the target's Wards already applied to this
			if by == null:
				amount = BattleUnit.damage_bonus(credit, other, amount)
			var type: int = by.get_attack_damage_type() if by != null else Stats.DamageType.MIGHT
			var hurt := other.take_damage(amount, wrack_level, type, true, by, true, true)   # passed on, not Pure
			target.get_tree().call_group("damage_tracker", "record_damage", credit, hurt)
		_show_cone(target, aim)

	## A faint crimson wedge fanning out past the target over the cleave's reach, fading
	## quickly. Shown on every cleaving hit, so the reach reads even when it hits no one.
	func _show_cone(target: BattleUnit, aim: Vector2) -> void:
		if not KeepsakeVfx.enabled() or not target.is_inside_tree():
			return
		var spacing: float = target.grid.cell_spacing() if target.grid != null else 55.0
		var inner := spacing * 0.35
		var outer := spacing * (effect.reach + 0.4)
		var half := deg_to_rad(effect.angle / 2.0)
		var points := PackedVector2Array()
		var arc := PackedVector2Array()
		var steps := 12
		for i in steps + 1:
			var a := -half + 2.0 * half * i / steps
			arc.append(Vector2.from_angle(a) * outer)
		for p in arc:
			points.append(p)
		for i in range(steps, -1, -1):
			points.append(Vector2.from_angle(-half + 2.0 * half * i / steps) * inner)
		var cone := Polygon2D.new()
		cone.polygon = points
		cone.color = Color(CONE_COLOR, 0.2)
		cone.z_index = 1
		var edge := Line2D.new()
		edge.points = arc
		edge.width = 1.5
		edge.default_color = Color(CONE_COLOR, 0.55)
		cone.add_child(edge)
		target.get_tree().current_scene.add_child(cone)
		cone.global_position = target.global_position
		cone.rotation = aim.angle()
		var tween := cone.create_tween()
		tween.tween_property(cone, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_callback(cone.queue_free)
