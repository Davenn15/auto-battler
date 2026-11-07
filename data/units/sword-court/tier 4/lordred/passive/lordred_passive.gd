class_name LordredPassive
extends Passive
## Gains Might, Insight, and Celerity the lower his health is.

## The bonus to each attribute as health nears zero. At half health he has half of it.
@export var max_bonus: float = 80.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(LowHealthFuryStatus.new(max_bonus))
