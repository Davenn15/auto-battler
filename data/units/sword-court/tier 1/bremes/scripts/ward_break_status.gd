class_name WardBreakStatus
extends Status
## Lowers all three of the unit's wards for a while.

const TEXT_COLOR := Color(0.7, 0.7, 0.75)

var reduction: float
var time_left: float


func _init(p_reduction: float, p_duration: float) -> void:
	reduction = p_reduction
	time_left = p_duration


func on_applied(unit: BattleUnit) -> void:
	unit.show_float_text("Sundered", TEXT_COLOR)


## Called when the Gambit hits a unit that's already sundered: keeps the stronger values.
func refresh(p_reduction: float, p_duration: float) -> void:
	reduction = maxf(reduction, p_reduction)
	time_left = maxf(time_left, p_duration)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat in Stats.WARD_FOR_TYPE.values():   # any of the three wards
		return value - reduction
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
