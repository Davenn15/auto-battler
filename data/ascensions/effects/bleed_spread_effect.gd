class_name BleedSpreadEffect
extends Passive
## An Ascension effect (Cerceval's hero Ascension): while he's alive, whenever an enemy dies
## with Bleed left in its pool (anyone's Bleed), Share of it passes to that enemy's nearest
## ally within Range Cells of it. Nothing passes on if no ally is that close.

@export_range(0.0, 1.0, 0.05) var share: float = 0.5
@export var range_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SpreadStatus.new(self))


class SpreadStatus extends Status:
	var effect: BleedSpreadEffect

	func _init(p_effect: BleedSpreadEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_enemy_bleed_death(unit: BattleUnit, victim: BattleUnit, bleed_left: float) -> void:
		var next := _nearest_ally(victim)
		if next == null:
			return
		Bleed.apply(next, bleed_left * effect.share, unit, false)   # already worked out: no bonus again
		CercevalFx.blood_trail(victim, next)

	## The living ally of `victim` nearest it (in hexes) within reach; ties go to the lower
	## instance id, so it never depends on the tree's order.
	func _nearest_ally(victim: BattleUnit) -> BattleUnit:
		var best: BattleUnit = null
		var best_d := effect.range_cells + 1
		for node in victim.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other == null or other == victim or not other.alive or other.team != victim.team:
				continue
			var d := victim.grid.get_distance(victim.cell, other.cell)
			if d < best_d or (d == best_d and best != null and other.get_instance_id() < best.get_instance_id()):
				best = other
				best_d = d
		return best
