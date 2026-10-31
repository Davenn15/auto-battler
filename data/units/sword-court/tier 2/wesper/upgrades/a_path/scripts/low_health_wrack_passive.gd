class_name LowHealthWrackPassive
extends Passive
## More wrack chance against targets below a share of their max health.

## Added to wrack chance (0.2 = +20 percentage points). Stacks with other bonuses.
@export var bonus_wrack_chance: float = 0.2
## Targets at or below this share of max health count (0.5 = half).
@export var health_threshold: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(LowHealthWrackStatus.new(bonus_wrack_chance, health_threshold))
