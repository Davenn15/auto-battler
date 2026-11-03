class_name WrackCountHitEffect
extends HitEffect
## Counts how many of the attacks it's attached to landed as wracks. Dodged attacks
## don't count, since hit effects don't run for them.

var count: int = 0


func apply(_target: BattleUnit, _dealt: float, wrack_level: int) -> void:
	if wrack_level > 0:
		count += wrack_level
