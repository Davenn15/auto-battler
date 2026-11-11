class_name TauntedStatus
extends Status
## Forced to attack the taunter for a while.

var taunter              # untyped: may be freed
var time_left: float


func _init(p_taunter: BattleUnit, p_duration: float) -> void:
	taunter = p_taunter
	time_left = p_duration


func on_applied(unit: BattleUnit) -> void:
	time_left *= unit.crowd_control_multiplier()
	unit.target = taunter
	unit.show_float_text("Taunted", Color(0.85, 0.15, 0.15))


func modify_target_choice(unit: BattleUnit, choice: BattleUnit, _exclude: BattleUnit) -> BattleUnit:
	if is_instance_valid(taunter) and unit._is_valid_target(taunter):
		return taunter
	return choice


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0 or not is_instance_valid(taunter) or not taunter.alive:
		unit.remove_status(self)
