class_name ReloadOnGainPassive
extends Passive
## Whenever the unit gains permanent stats, its next attack is a pistol shot.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ReloadOnGainStatus.new())
