class_name Sap
extends RefCounted
## Sap: one unit stealing something from another. The victim loses it and the thief gains
## it, for the rest of combat. Everything stolen from or by a unit is kept in one
## SappedStatus on that unit.


## Steals `amount` of `stat` from `victim` and gives it to `thief`.
static func stat(thief: BattleUnit, victim: BattleUnit, which: Stats.Stat, amount: float) -> void:
	_ledger(victim).add(which, -amount)
	_ledger(thief).add(which, amount)


static func _ledger(unit: BattleUnit) -> SappedStatus:
	for status in unit.statuses:
		if status is SappedStatus:
			return status
	var ledger := SappedStatus.new()
	unit.add_status(ledger)
	return ledger
