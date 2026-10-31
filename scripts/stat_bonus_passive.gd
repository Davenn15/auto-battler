class_name StatBonusPassive
extends Passive
## A flat bonus to one stat for the whole battle.

@export var stat: Stats.Stat = Stats.Stat.INSIGHT
@export var amount: float = 60.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StatBonusStatus.new(stat, amount))
