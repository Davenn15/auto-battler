class_name WrackPierceEffect
extends Passive
## The unit's wracking hits ignore part of the target's ward.

@export_range(0.0, 1.0, 0.05) var ignored: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Pierce.new(ignored))


class Pierce extends Status:
	var ignored: float

	func _init(p_ignored: float) -> void:
		ignored = p_ignored

	func modify_target_ward(_unit: BattleUnit, target: BattleUnit, ward: float, wrack_level: int) -> float:
		if wrack_level <= 0:
			return ward
		KeepsakeVfx.sparks(target)
		return ward * (1.0 - ignored)
