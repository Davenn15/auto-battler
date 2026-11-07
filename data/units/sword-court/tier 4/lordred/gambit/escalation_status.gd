class_name EscalationStatus
extends Status
## Counts the unit's casts this combat. Each one raises its max charge, so the next cast
## takes longer to build. Max charge goes back to normal when combat ends.

var casts: int = 0
var _extra_charge: float = 0.0


## Statuses a Gambit creates block charge until they end. This lasts all battle, so it mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func escalate(unit: BattleUnit, charge_step: float) -> void:
	casts += 1
	_extra_charge += charge_step
	unit.set_max_charge(unit.max_charge + charge_step)


func on_removed(unit: BattleUnit) -> void:
	unit.set_max_charge(unit.max_charge - _extra_charge)
