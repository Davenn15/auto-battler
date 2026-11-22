class_name KillChargeStatus
extends Status
## Silt A2: getting a kill (any direct damage: attacks, his empowered Insight hits, splash)
## fills his Charge.

var _counted := {}   # enemies already counted, so one kill never fills twice


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func on_direct_damage_dealt(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
	if not is_instance_valid(target) or target.alive or target.team == unit.team:
		return
	if _counted.has(target.get_instance_id()):
		return
	_counted[target.get_instance_id()] = true
	unit.fill_charge()
