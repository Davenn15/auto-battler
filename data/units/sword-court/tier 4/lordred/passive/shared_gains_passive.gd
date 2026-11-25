class_name SharedGainsPassive
extends Passive
## Lordred's passive: whenever an ally gains stats for the rest of combat (Glory included),
## he gains a share of them too.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SharedGainsStatus.new(share))
