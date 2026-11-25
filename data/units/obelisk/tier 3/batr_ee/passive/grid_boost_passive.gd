class_name GridBoostPassive
extends Passive
## Upgrades to Battery's passive (GridPassive), granted by its upgrades. Several add up.
##   A: cast_voltage_share (Voltage when a unit in its aura casts its Gambit).
##   A1: wrack_per_voltage (Wrack Chance per Voltage, for Battery).

## Extra hex cells of passive range.
@export var range_bonus: int = 0
## A: when a unit in the aura (not Battery) casts its Gambit, Battery gains this share of
## that unit's max Charge as Voltage (0.1 = a 100-Charge unit gives 10).
@export var cast_voltage_share: float = 0.0
## A1: Wrack Chance Battery gains per Voltage it has (0.01 = +1% per stack).
@export var wrack_per_voltage: float = 0.0


## Every boost on `unit`, added up: {range, cast_voltage_share, wrack_per_voltage}. Reads
## the unit's passive list, so it works before any battle-start status exists.
static func boosts(unit: BattleUnit) -> Dictionary:
	var result := {"range": 0, "cast_voltage_share": 0.0, "wrack_per_voltage": 0.0}
	for passive in unit.passives:
		if passive is GridBoostPassive:
			result["range"] += passive.range_bonus
			result["cast_voltage_share"] += passive.cast_voltage_share
			result["wrack_per_voltage"] += passive.wrack_per_voltage
	return result
