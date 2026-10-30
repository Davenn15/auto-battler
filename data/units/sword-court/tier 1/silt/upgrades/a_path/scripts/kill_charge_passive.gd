class_name KillChargePassive
extends Passive
## Killing an enemy with an attack fills the unit's charge.

func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(KillChargeStatus.new())
