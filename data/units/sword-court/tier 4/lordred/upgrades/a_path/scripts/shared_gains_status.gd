class_name SharedGainsStatus
extends Status
## Whenever an ally gains permanent stats, the unit gains a share of them too.

var share: float   # 0.5 = half of what the ally gained
var _unit: BattleUnit
var _listening: Array[BattleUnit] = []


func _init(p_share: float) -> void:
	share = p_share


func on_applied(unit: BattleUnit) -> void:
	_unit = unit
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally != null and ally != unit and ally.team == unit.team:
			ally.permanent_stats_gained.connect(_on_ally_gain)
			_listening.append(ally)


func on_removed(_unit_removed: BattleUnit) -> void:
	for ally in _listening:
		if is_instance_valid(ally) and ally.permanent_stats_gained.is_connected(_on_ally_gain):
			ally.permanent_stats_gained.disconnect(_on_ally_gain)
	_listening.clear()


## Any permanent gain an ally makes (see BattleUnit.gain_permanent_stats), except gains
## that were themselves copied from someone (so two Lordreds don't copy each other forever).
func _on_ally_gain(_ally: BattleUnit, gains: Dictionary, copied: bool) -> void:
	if copied or not is_instance_valid(_unit) or not _unit.alive:
		return
	for stat in gains:
		if gains[stat] > 0.0:
			_unit.add_status(PermanentStatStatus.new(stat, gains[stat] * share, true))
