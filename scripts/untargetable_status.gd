class_name UntargetableStatus
extends Status
## Enemies drop the unit as their target and can't pick it for a while.

const FADE := 0.45   # the unit's opacity while hidden

var time_left: float


func _init(p_duration: float) -> void:
	time_left = p_duration


func on_applied(unit: BattleUnit) -> void:
	unit.modulate.a = FADE


func on_removed(unit: BattleUnit) -> void:
	unit.modulate.a = 1.0


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func blocks_targeting(_unit: BattleUnit) -> bool:
	return true
