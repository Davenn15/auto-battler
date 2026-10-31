class_name StatBonusStatus
extends Status

var stat: Stats.Stat
var amount: float


func _init(p_stat: Stats.Stat, p_amount: float) -> void:
	stat = p_stat
	amount = p_amount


func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
	return value + amount if which == stat else value
