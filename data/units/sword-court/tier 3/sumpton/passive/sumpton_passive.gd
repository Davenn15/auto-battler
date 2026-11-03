class_name SumptonPassive
extends Passive
## The unit's attacks briefly stun enemies.

## Seconds each attack stuns for.
@export var stun_duration: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StunAttacksStatus.new(stun_duration))
