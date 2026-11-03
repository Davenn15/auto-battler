class_name DelayedDamagePassive
extends Passive
## All damage the unit takes is dealt over time instead of instantly.

## Seconds over which each hit's damage is dealt.
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DelayedDamageStatus.new(duration))
