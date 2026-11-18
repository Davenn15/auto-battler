class_name CcImmuneShieldedStatus
extends Status
## Garth A1: Immovability while shielded.

const IMMOVABILITY := 60.0


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.IMMOVABILITY and unit.get_shield() > 0.0:
		return value + IMMOVABILITY
	return value
