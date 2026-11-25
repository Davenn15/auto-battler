class_name WrackBurstEffect
extends Passive
## Exploding Top's Wrack Empower: when the unit's Gambit damage Wracks, the target
## explodes, dealing Share of that damage to every other enemy within Radius Cells.

@export var share: float = 0.2
@export var radius_cells: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Burst.new(self))


class Burst extends Status:
	var effect: WrackBurstEffect

	func _init(p_effect: WrackBurstEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		if target.last_hit_attacker != null or target.incoming_wrack_level <= 0 or unit.grid == null:
			return
		var type := target.last_damage_type
		KeepsakeVfx.missile_blast(target.get_parent(), target.global_position, 30.0, KeepsakeVfx.BURST_COLOR)
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy != target and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(target.cell, enemy.cell) <= effect.radius_cells:
				var dealt := enemy.take_damage(amount * effect.share, 0, type, false, null)
				unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
