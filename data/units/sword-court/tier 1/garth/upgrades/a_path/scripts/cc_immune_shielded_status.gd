class_name CcImmuneShieldedStatus
extends Status

func blocks_crowd_control(unit: BattleUnit) -> bool:
	return unit.get_shield() > 0.0
