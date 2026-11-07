class_name NotePassive
extends Passive
## Adds one of Prancelot's extra notes, sent every `every` attacks.

@export_enum("Energizing", "Jolting", "Silencing") var kind: int = 0
@export var every: int = 3
## How far the note can be sent, in hex cells.
@export var range_cells: int = 4
## Celerity (Energizing) or wrack chance (Jolting) given, before Gambit potency.
## Not used by Silencing.
@export var amount: float = 30.0
## Seconds the effect lasts, before Gambit potency for Silencing.
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	match kind:
		0:
			unit.add_status(EnergizingNoteStatus.new(every, range_cells, amount, duration))
		1:
			unit.add_status(JoltingNoteStatus.new(every, range_cells, amount, duration))
		2:
			unit.add_status(SilencingNoteStatus.new(every, range_cells, duration))
