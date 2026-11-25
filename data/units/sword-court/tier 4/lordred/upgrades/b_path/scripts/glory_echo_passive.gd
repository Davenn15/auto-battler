class_name GloryEchoPassive
extends Passive
## Lordred B1: the first time each combat an ally gains Glory, he gains Glory too (within
## his own Glory cap).


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GloryEchoStatus.new())


class GloryEchoStatus extends Status:
	var _unit: BattleUnit
	var _done := false
	var _listening: Array[BattleUnit] = []

	func blocks_charge_gain(_unit_in: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		_unit = unit
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally != null and ally != unit and ally.team == unit.team:
				ally.glory_earned.connect(_on_ally_glory)
				_listening.append(ally)

	func on_removed(_unit_in: BattleUnit) -> void:
		for ally in _listening:
			if is_instance_valid(ally) and ally.glory_earned.is_connected(_on_ally_glory):
				ally.glory_earned.disconnect(_on_ally_glory)
		_listening.clear()

	func _on_ally_glory(_ally: BattleUnit) -> void:
		if _done or not is_instance_valid(_unit) or not _unit.alive:
			return
		_done = true
		_unit.gain_glory()
