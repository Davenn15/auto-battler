class_name GeomondPassive
extends Passive
## Celerity the unit would gain becomes Might and Insight instead, and its attacks deal
## extra damage based on the target's max health.

## Extra attack damage as a fraction of the target's max health (0.03 = 3%).
@export_range(0.0, 0.2, 0.005) var max_health_percent: float = 0.03


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CelerityConversionStatus.new())
	unit.add_status(MaxHealthAttacksStatus.new(max_health_percent))
