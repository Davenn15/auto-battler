class_name PrancelotPassive
extends Passive
## Every other attack sends a soothing note to the most hurt nearby ally: a burst of
## healing over time.

@export var every: int = 2
## How far a note can be sent, in hex cells.
@export var range_cells: int = 4
## Healing per second the note gives, before Gambit potency.
@export var heal_per_second: float = 30.0
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SoothingNoteStatus.new(every, range_cells, heal_per_second, duration))
