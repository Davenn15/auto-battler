class_name IndestructibleStatus
extends Status
## Each time the unit gains a shield, it gets a burst of extra dodge chance for a moment.
## A new shield restarts the burst rather than stacking it.

var bonus_dodge: float
var duration: float
var _time_left: float = 0.0


func _init(p_bonus_dodge: float, p_duration: float) -> void:
	bonus_dodge = p_bonus_dodge
	duration = p_duration


func on_status_added(_unit: BattleUnit, added: Status) -> void:
	if added is ShieldStatus:
		_time_left = duration


func tick(_unit: BattleUnit, delta: float) -> void:
	_time_left = maxf(_time_left - delta, 0.0)


func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
	return chance + bonus_dodge if _time_left > 0.0 else chance
