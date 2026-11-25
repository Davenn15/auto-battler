class_name BloodfeastEffect
extends Passive
## An Ascension effect (Sword Court, Bloodfeast): when an enemy dies with Bleed left, the ally
## with the lowest health within Radius Cells of it is healed for Heal Share of that ally's
## max health plus Bleed Share of the Bleed the enemy had left. Once per death.

@export var heal_share: float = 0.08
@export var bleed_share: float = 0.5
@export var radius_cells: int = 3

const META := "bloodfeast_fed"


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BloodfeastStatus.new(self))


class BloodfeastStatus extends Status:
	var effect: BloodfeastEffect

	func _init(p_effect: BloodfeastEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## Every unit in the army hears each death: the first to hear it feeds the army.
	func on_enemy_bleed_death(unit: BattleUnit, victim: BattleUnit, bleed_left: float) -> void:
		var key := "%s_%d" % [BloodfeastEffect.META, unit.team]
		if not is_instance_valid(victim) or victim.has_meta(key):
			return
		victim.set_meta(key, true)
		var best: BattleUnit = null
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or not ally.alive or ally.team != unit.team \
					or unit.grid.get_distance(victim.cell, ally.cell) > effect.radius_cells:
				continue
			if best == null or ally.health < best.health:
				best = ally
		if best == null:
			return
		best.heal(best.max_health * effect.heal_share + bleed_left * effect.bleed_share, unit.get_instance_id())
		KeepsakeVfx.flourish(best, Color(0.8, 0.1, 0.15))
