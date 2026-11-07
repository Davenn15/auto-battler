class_name StarburnPassive
extends Passive
## The unit's attacks leave a ramping burn worth a share of their damage.

## Share of each hit's damage the burn deals again (0.4 = 40%).
@export_range(0.0, 2.0, 0.05) var share: float = 0.4
## Seconds each burn lasts.
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StarburnStatus.new(share, duration))
