class_name ExecutePassive
extends Passive
## Hitting an enemy that's left at or below a share of its max health kills it outright.

## 0.15 = an enemy left at 15% health or less dies.
@export var health_threshold: float = 0.15


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ExecuteStatus.new(health_threshold))
