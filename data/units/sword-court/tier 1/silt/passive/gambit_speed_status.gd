class_name GambitSpeedStatus
extends Status
## Stacks attack speed each time the unit Acts. Lasts until the status is cleared,
## which happens when the next battle starts.

var celerity_per_gambit: float
var stacks: int = 0


func _init(p_celerity_per_gambit: float) -> void:
	celerity_per_gambit = p_celerity_per_gambit


func on_gambit(_unit: BattleUnit) -> void:
	stacks += 1


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.CELERITY:
		return value + stacks * celerity_per_gambit
	return value
