class_name WardStealPassive
extends Passive
## Grouser A1: whenever he takes ward from an enemy, he gains the same amount of that ward
## for Duration seconds (see WardShiftStatus.shred).

@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StealStatus.new(duration))


## Just a marker that WardShiftStatus.shred looks for.
class StealStatus extends Status:
	var duration: float

	func _init(p_duration: float) -> void:
		duration = p_duration
