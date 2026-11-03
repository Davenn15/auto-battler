class_name WrackTallyPassive
extends Passive
## Each ally wrack adds one blade to the unit's next Blade Toss.

## Most extra blades that can be banked at once.
@export var max_bonus_blades: int = 4


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(WrackTallyStatus.new(max_bonus_blades))
