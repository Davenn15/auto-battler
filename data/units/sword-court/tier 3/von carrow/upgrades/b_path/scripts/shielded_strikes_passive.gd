class_name ShieldedStrikesPassive
extends Passive
## While shielded, the unit's attacks deal bonus max-health damage.

## Extra damage as a share of the target's max health (0.04 = 4%).
@export_range(0.0, 0.2, 0.005) var percent: float = 0.04


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldedStrikesStatus.new(percent))
