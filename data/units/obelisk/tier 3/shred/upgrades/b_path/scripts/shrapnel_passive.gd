class_name ShredShrapnelPassive
extends Passive
## Shred B1: its attacks gain the Hit Effect: a shrapnel blast at a random other enemy
## within Radius cells of the target, dealing Damage (+ Might Scaling of Shred's Might) as
## Might damage. It fizzles if there's no other enemy there.

@export var damage: float = 20.0
@export var might_scaling: float = 0.2
@export var radius: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShrapnelStatus.new(self))


class ShrapnelStatus extends Status:
	var passive: ShredShrapnelPassive

	func _init(p_passive: ShredShrapnelPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		var amount := Stats.scaled(passive.damage, passive.might_scaling, unit.get_stat(Stats.Stat.MIGHT))
		return ShrapnelHit.new(unit.get_credit_id(), unit.team, amount, passive.radius)


class ShrapnelHit extends HitEffect:
	var credit_id: int
	var team: int
	var amount: float
	var radius: int

	func _init(p_credit: int, p_team: int, p_amount: float, p_radius: int) -> void:
		credit_id = p_credit
		team = p_team
		amount = p_amount
		radius = p_radius

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not is_instance_valid(target) or not target.is_inside_tree():
			return
		var options: Array = []
		for node in target.get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or unit == target or not unit.alive or unit.team == team or not unit.is_targetable():
				continue
			if target.grid.get_distance(target.cell, unit.cell) <= radius:
				options.append(unit)
		if options.is_empty():
			return
		var victim: BattleUnit = CombatRng.pick(options)
		ShredFx.shrapnel(target.global_position, victim)
		var dealt := victim.take_damage(BattleUnit.damage_bonus(credit_id, victim, amount), 0, Stats.DamageType.MIGHT)
		victim.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
