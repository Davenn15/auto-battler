class_name ConeCleaveEffect
extends Passive
## An Ascension effect (Lord's Reach): the unit's attacks (Gambit attacks included) gain
## the Hit Effect: every other enemy in a cone past the target, up to Reach cells beyond
## it and Angle degrees wide, takes Share of the damage the target took.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5
@export var reach: int = 2
@export_range(10.0, 180.0, 5.0) var angle: float = 60.0

const SLASH_COLOR := Color(0.85, 0.15, 0.15)


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
		var hit_any := false
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
			var hurt := other.take_damage(amount, wrack_level, type, true, by)
			target.get_tree().call_group("damage_tracker", "record_damage", credit, hurt)
			hit_any = true
		if hit_any:
			KeepsakeVfx.swing(target, aim.angle(), SLASH_COLOR)
