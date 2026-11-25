class_name FeedbackLoopEffect
extends Passive
## An Ascension effect (Obelisk, Feedback Loop): each unit gains Regen Per Stack health
## regeneration for every Mono-Virus stack on enemies within Radius Cells of it, counting at
## most Max Stacks.

@export var regen_per_stack: float = 0.75
@export var radius_cells: int = 3
@export var max_stacks: int = 20


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(FeedbackStatus.new(self))


class FeedbackStatus extends Status:
	var effect: FeedbackLoopEffect

	func _init(p_effect: FeedbackLoopEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_health_regen(unit: BattleUnit, regen: float) -> float:
		if not unit.is_inside_tree():
			return regen
		var stacks := 0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= effect.radius_cells:
				stacks += MonoVirusStatus.stacks_on(enemy)
		return regen + effect.regen_per_stack * mini(stacks, effect.max_stacks)
