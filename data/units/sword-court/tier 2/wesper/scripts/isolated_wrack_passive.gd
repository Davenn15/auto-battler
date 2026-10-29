class_name IsolatedWrackPassive
extends Passive
## Increases wrack chance against targets that aren't near any of their allies.

## Added to wrack chance against an isolated target (0.25 = +25 percentage points).
@export var bonus_wrack_chance: float = 0.25
## A target counts as isolated if no living ally is within this many hex cells of it.
@export var isolation_range_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(IsolatedWrackStatus.new(bonus_wrack_chance, isolation_range_cells))
