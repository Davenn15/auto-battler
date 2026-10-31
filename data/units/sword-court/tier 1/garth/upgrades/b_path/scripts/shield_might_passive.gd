class_name ShieldMightPassive
extends Passive
## The unit gains Might while it has a shield.

@export var might: float = 40.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldWardStatus.new({Stats.Stat.MIGHT: might}))
