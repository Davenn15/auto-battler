class_name CcImmuneShieldedPassive
extends Passive
## The unit has Immovability while it has a shield (see CcImmuneShieldedStatus).

func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CcImmuneShieldedStatus.new())
