class_name PermanentStatStatus
extends Status
## A bonus to one stat for the rest of combat. Counts as gaining permanent stats.

var stat: Stats.Stat
var amount: float


func _init(p_stat: Stats.Stat, p_amount: float) -> void:
	stat = p_stat
	amount = p_amount


func is_permanent_stat_gain() -> bool:
	return true


## Gambit-made statuses block charge until they end. This never ends, so it mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
	return value + amount if which == stat else value

func get_permanent_stat_gains() -> Dictionary:
	return {stat: amount}
