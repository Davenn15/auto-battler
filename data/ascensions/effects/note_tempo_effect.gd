class_name NoteTempoEffect
extends Passive
## An Ascension effect (Virtuoso): Prancelot's notes (every NoteStatus on the unit: his
## soothing note and any his upgrades add) come Fewer attacks sooner, but never more often
## than every attack. Runs after the unit's own passives have added their notes.

## How many fewer attacks each note takes.
@export var fewer: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	for status in unit.statuses:
		if status is NoteStatus:
			status.every = maxi(1, status.every - fewer)
