class_name SummonLifetimeStatus
extends Status
## Removes a summoned unit after a set time.

var time_left: float


func _init(p_duration: float) -> void:
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.kill()
