class_name Gambit
extends Resource
## Base class for unit abilities. Make a new script that extends this one for each
## kind of Action, override can_use() and execute(), then save instances as .tres files.

@export var gambit_name: String = "Gambit"
## Seconds the unit spends Acting before the effect happens. 0 = instant.
@export var cast_time: float = 0.0
## Shown in the unit info panel.
@export_multiline var description: String = ""

## Checked before charge is spent. Return false when the Action has no valid use right
## now (e.g. no enemy in range); the unit keeps its full charge and checks again later.
func can_use(_caster: BattleUnit) -> bool:
	return true


## The effect itself. Runs when Act time ends (immediately if cast_time is 0).
## The caster or its target may have died while Acting, so check before using them.
func execute(_caster: BattleUnit) -> void:
	pass
