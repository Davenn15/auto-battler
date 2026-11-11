class_name GridBoostPassive
extends Passive
## Upgrades to BATR.EE's passive (GridPassive), granted by its upgrades.
##   A1: whole_board = the passive covers the entire battlefield.
##   B: phased_voltage = Voltage per second while BATR.EE is Phased.

@export var whole_board: bool = false
@export var phased_voltage: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BoostStatus.new(self))


## Every boost on `unit`, added up: {"whole_board": bool, "phased_voltage": float}.
static func boosts(unit: BattleUnit) -> Dictionary:
	var result := {"whole_board": false, "phased_voltage": 0.0}
	for status in unit.statuses:
		if status is BoostStatus:
			result["whole_board"] = result["whole_board"] or status.passive.whole_board
			result["phased_voltage"] += status.passive.phased_voltage
	return result


class BoostStatus extends Status:
	var passive: GridBoostPassive

	func _init(p_passive: GridBoostPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
