class_name WrackTallyStatus
extends Status
## Listens to every ally's attacks. Each wrack banks one extra blade for the unit's next
## Blade Toss, up to a cap.

var max_bonus: int
var _bonus: int = 0
var _listening: Array[BattleUnit] = []


func _init(p_max_bonus: int) -> void:
	max_bonus = p_max_bonus


func on_applied(unit: BattleUnit) -> void:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally != null and ally != unit and ally.team == unit.team:
			ally.wracked.connect(_on_ally_wracked)
			_listening.append(ally)


func on_removed(_unit: BattleUnit) -> void:
	for ally in _listening:
		if is_instance_valid(ally) and ally.wracked.is_connected(_on_ally_wracked):
			ally.wracked.disconnect(_on_ally_wracked)
	_listening.clear()


func _on_ally_wracked(_ally: BattleUnit) -> void:
	_bonus = mini(_bonus + 1, max_bonus)


## Returns the banked blades and resets the count.
func take() -> int:
	var amount := _bonus
	_bonus = 0
	return amount
