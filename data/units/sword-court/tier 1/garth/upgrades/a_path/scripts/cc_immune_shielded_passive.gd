class_name CcImmuneShieldedPassive
extends Passive
## The unit can't be crowd controlled while it has a shield.

func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CcImmuneShieldedStatus.new())
