class_name Passive
extends Resource
## Base class for passive abilities. Like Actions, these are shared resources, so they
## hold settings only. Anything that changes during a battle belongs in a Status that
## the passive attaches to the unit.

@export var passive_name: String = "Passive"
## Shown in the unit info panel.
@export_multiline var description: String = ""

## Called at the start of every battle, after the unit's statuses have been cleared.
## Attach statuses here with unit.add_status().
func on_battle_start(_unit: BattleUnit) -> void:
	pass
