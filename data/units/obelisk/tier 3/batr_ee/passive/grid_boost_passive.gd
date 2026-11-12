class_name GridBoostPassive
extends Passive
## Upgrades to BATR.EE's passive (GridPassive), granted by its upgrades. Several add up.
##   A (Charged): range_bonus and insight_bonus.
##   B1: max_voltage_bonus and voltage_per_second.

## Extra hex cells of passive range.
@export var range_bonus: int = 0
## Extra Insight allies in range gain.
@export var insight_bonus: float = 0.0
## Extra Voltage BATR.EE can hold.
@export var max_voltage_bonus: float = 0.0
## Voltage BATR.EE gains every second.
@export var voltage_per_second: float = 0.0


## Every boost on `unit`, added up: {range, insight, max_voltage, voltage_per_second}.
## Reads the unit's passive list, so it works before any battle-start status exists.
static func boosts(unit: BattleUnit) -> Dictionary:
	var result := {"range": 0, "insight": 0.0, "max_voltage": 0.0, "voltage_per_second": 0.0}
	for passive in unit.passives:
		if passive is GridBoostPassive:
			result["range"] += passive.range_bonus
			result["insight"] += passive.insight_bonus
			result["max_voltage"] += passive.max_voltage_bonus
			result["voltage_per_second"] += passive.voltage_per_second
	return result

