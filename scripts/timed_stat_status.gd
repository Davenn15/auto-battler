class_name TimedStatStatus
extends Status
## A bonus to one stat for a while. Several stack.

var stat: Stats.Stat
var amount: float
var time_left: float


func _init(p_stat: Stats.Stat, p_amount: float, p_duration: float) -> void:
	stat = p_stat
	amount = p_amount
	time_left = p_duration


func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
	return value + amount if which == stat else value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
