class_name DamageCapPassive
extends Passive
## No single hit can take more than a share of the unit's max health.

## 0.08 = one hit takes at most 8% of max health. Wards apply first, then this cap.
@export var max_share_of_health: float = 0.08


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DamageCapStatus.new(max_share_of_health))
