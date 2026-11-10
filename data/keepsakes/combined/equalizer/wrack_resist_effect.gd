class_name WrackResistEffect
extends Passive
## Wracking hits deal less damage to the unit.

@export_range(0.0, 1.0, 0.05) var reduction: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Steady.new(reduction))


class Steady extends Status:
	var reduction: float

	func _init(p_reduction: float) -> void:
		reduction = p_reduction

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		return damage * (1.0 - reduction) if unit.incoming_wrack_level > 0 else damage
