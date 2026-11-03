class_name HitEffect
extends RefCounted
## Something extra that happens when one particular attack lands. Statuses create these
## when the attack is made (Status.get_hit_effect), so the effect still happens even if
## the status has ended by the time a projectile arrives. It keeps its own copy of
## everything it needs, rather than relying on the status or the attacker still existing.

## Called when the attack lands. `target` may have just been killed by the hit.
## `wrack_level`: 0 = normal, 1 = wrack, 2 = Hyper-Wrack.
func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	pass
