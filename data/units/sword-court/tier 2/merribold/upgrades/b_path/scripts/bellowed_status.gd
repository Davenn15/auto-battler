class_name BellowedStatus
extends Status
## A change to Might, and optionally extra regen, for a while, from a Bellow.

var source_id: int
var might_change: float   # positive for allies, negative for enemies
var regen: float
var time_left: float


func _init(p_source_id: int, p_might_change: float, p_regen: float, p_duration: float) -> void:
	source_id = p_source_id
	might_change = p_might_change
	regen = p_regen
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	return value + might_change if stat == Stats.Stat.MIGHT else value


func modify_health_regen(_unit: BattleUnit, value: float) -> float:
	return value + regen


## A buff (or debuff), not a casting state, so it never blocks charge.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false
