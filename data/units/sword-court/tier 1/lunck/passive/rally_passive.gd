class_name RallyPassive
extends Passive
## Allies within range get bonus Celerity for as long as they stay in range.

## Celerity granted to each ally in range.
@export var celerity_bonus: float = 20.0
## Range in hex cells. The Rally gambit uses this same range.
@export var range_cells: int = 2
## Whether Lunck benefits from his own aura.
@export var include_self: bool = false


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RallyAuraStatus.new(celerity_bonus, range_cells, include_self))
