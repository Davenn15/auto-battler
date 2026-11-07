class_name TwirlStatus
extends Status
## While twirling, any shield the unit would gain is held back and handed over at the end.

var banked: float = 0.0


func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
	banked += amount
	return 0.0
