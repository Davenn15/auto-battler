class_name MerriboldPassive
extends Passive
## The lower the unit's health, the faster it regenerates.

## Extra regen per second the unit has at zero health. The bonus scales linearly with
## missing health, so at half health it's half of this.
@export var max_bonus_regen: float = 30.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(LowHealthRegenStatus.new(max_bonus_regen))
