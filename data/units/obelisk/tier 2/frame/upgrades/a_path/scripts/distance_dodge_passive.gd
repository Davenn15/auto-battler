class_name DistanceDodgePassive
extends Passive
## Frame A (Highswinging): extra dodge chance against hits from attackers farther away:
## Per Hex for every hex past the first, up to Max Bonus. Hits with no attacker (Gambit
## blasts, damage over time) get none.

@export_range(0.0, 1.0, 0.01) var per_hex: float = 0.08
@export_range(0.0, 1.0, 0.01) var max_bonus: float = 0.32


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DistanceDodgeStatus.new(self))


class DistanceDodgeStatus extends Status:
	var passive: DistanceDodgePassive

	func _init(p_passive: DistanceDodgePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_dodge_chance(unit: BattleUnit, chance: float) -> float:
		var attacker := unit.dodging_attacker
		if not is_instance_valid(attacker):
			return chance
		var hexes := unit.grid.get_distance(unit.cell, attacker.cell)
		return chance + minf(maxf(hexes - 1, 0) * passive.per_hex, passive.max_bonus)
