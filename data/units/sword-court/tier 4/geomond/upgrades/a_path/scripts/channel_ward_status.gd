class_name ChannelWardStatus
extends Status
## Extra Might, Insight, and Celerity Ward for a short time.

var bonus: float
var time_left: float


func _init(p_bonus: float, p_duration: float) -> void:
	bonus = p_bonus
	time_left = p_duration


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
			return value + bonus
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
