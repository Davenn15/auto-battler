class_name WardShredStatus
extends Status
## Lowers all three wards for the rest of combat. Repeated hits add more, up to a cap.

var amount: float = 0.0


## Lowers wards by `more`, but never by more than `cap` in total.
func add(more: float, cap: float) -> void:
	amount = minf(amount + more, cap)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
			return value - amount
	return value
