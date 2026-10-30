class_name KillChargeStatus
extends Status

func on_kill(unit: BattleUnit, _victim: BattleUnit) -> void:
	unit.fill_charge()
