class_name SharedGainsPassive
extends Passive
## Whenever an ally gains permanent stats, the unit gains a share of them too.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SharedGainsStatus.new(share))
