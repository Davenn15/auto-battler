class_name DistanceGuardEffect
extends Passive
## Longshot's Celerity Ward Empower: the unit takes Per Cell less damage from an attacker
## for each cell it is away past the first, up to Max Reduction.

@export var per_cell: float = 0.1
@export var max_reduction: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Guard.new(self))


class Guard extends Status:
	var effect: DistanceGuardEffect

	func _init(p_effect: DistanceGuardEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		var attacker := unit.incoming_attacker
		if attacker == null or not is_instance_valid(attacker) or unit.grid == null:
			return damage
		var cells := unit.grid.get_distance(unit.cell, attacker.cell)
		return damage * (1.0 - clampf(effect.per_cell * (cells - 1), 0.0, effect.max_reduction))

	func reduces_damage(_unit: BattleUnit) -> bool:
		return true
