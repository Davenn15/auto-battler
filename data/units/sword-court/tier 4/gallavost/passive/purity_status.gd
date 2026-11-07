class_name PurityStatus
extends Status
## While the unit has no shield, all of its damage skips wards.

var starting_shield: float = 0.0   # the shield she started the battle with, for her rebuild
var rebuilt: bool = false   # she gets one rebuild per combat

func ignores_wards(unit: BattleUnit) -> bool:
	return unit.get_shield() <= 0.0
