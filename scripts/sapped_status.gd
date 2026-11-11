class_name SappedStatus
extends Status
## Every stat a unit has had stolen (negative) or has stolen (positive) this combat.

var changes: Dictionary = {}   # Stats.Stat -> amount


func add(stat: Stats.Stat, amount: float) -> void:
	changes[stat] = changes.get(stat, 0.0) + amount


## Sap can happen during a Gambit, and this lasts all combat, so it mustn't block charge.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	var change: float = changes.get(stat, 0.0)
	if change < 0.0:
		change *= unit.debuff_multiplier()   # losses hurt less on units that resist debuffs
	return value + change
