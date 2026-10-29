class_name IsolatedWrackStatus
extends Status
## Adds wrack chance to attacks against targets that have no living ally nearby.

var bonus: float             # added to wrack chance (0.25 = +25 percentage points)
var isolation_range: int     # in hex cells; an ally this close or closer means "not isolated"


func _init(p_bonus: float, p_isolation_range: int) -> void:
	bonus = p_bonus
	isolation_range = p_isolation_range


func modify_wrack_chance(unit: BattleUnit, target: BattleUnit, chance: float) -> float:
	if _is_isolated(unit, target):
		return chance + bonus
	return chance


func _is_isolated(unit: BattleUnit, target: BattleUnit) -> bool:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other == null or other == target or not other.alive or other.team != target.team:
			continue
		if unit.grid.get_distance(target.cell, other.cell) <= isolation_range:
			return false
	return true
