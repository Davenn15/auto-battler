class_name ShieldWardPassive
extends Passive
## While the unit has a shield, it gains an amount of each ward.

## Ward gained while shielded. With the default ward formula, 100 halves damage of that type.
@export var might_ward: float = 50.0
@export var insight_ward: float = 50.0
@export var celerity_ward: float = 50.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldWardStatus.new({
		Stats.Stat.MIGHT_WARD: might_ward,
		Stats.Stat.INSIGHT_WARD: insight_ward,
		Stats.Stat.CELERITY_WARD: celerity_ward,
	}))
