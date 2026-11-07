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
			ally.status_added.connect(_on_ally_status)
			_listening.append(ally)


func on_removed(_unit_removed: BattleUnit) -> void:
	for ally in _listening:
		if is_instance_valid(ally) and ally.status_added.is_connected(_on_ally_status):
			ally.status_added.disconnect(_on_ally_status)
	_listening.clear()


func _on_ally_status(_ally: BattleUnit, added: Status) -> void:
	if not is_instance_valid(_unit) or not _unit.alive:
		return
	var gains := added.get_permanent_stat_gains()
	for stat in gains:
		_unit.add_status(PermanentStatStatus.new(stat, gains[stat] * share))
