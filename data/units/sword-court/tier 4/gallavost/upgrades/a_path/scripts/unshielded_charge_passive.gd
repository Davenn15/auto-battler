class_name UnshieldedChargePassive
extends Passive
## While the unit has no shield, it gains charge over time.

## Charge per second while unshielded (multiplied by Insight only under the old rule; see Stats.charge_multiplier).
@export var per_second: float = 8.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(UnshieldedChargeStatus.new(per_second))
