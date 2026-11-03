class_name LowHealthWardPassive
extends Passive
## The lower the unit's health, the higher its wards.

## Added to all three wards at zero health. The bonus scales with missing health, so at
## half health it's half of this.
@export var max_ward_bonus: float = 60.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(LowHealthWardStatus.new(max_ward_bonus))
