class_name HitEffect
extends RefCounted
## A Hit Effect: the game's official name (and description keyphrase, "Hit Effect: ...")
## for anything the attacker's attack does to its target once the attack lands. Every
## Hit Effect in the game is one of these, so mechanics that care about Hit Effects can
## find them all here, in the list each attack carries (BattleUnit._attack).
## Not Hit Effects: things that happen when a unit attacks (Status.on_attack), passives
## that merely watch hits land (Status.on_attack_hit), and changes to the attack's own
## damage (Status.modify_outgoing_damage).
##
## Something extra that happens when one particular attack lands. Statuses create these
## when the attack is made (Status.get_hit_effect), so the effect still happens even if
## the status has ended by the time a projectile arrives. It keeps its own copy of
## everything it needs, rather than relying on the status or the attacker still existing.

## Called when the attack lands. `target` may have just been killed by the hit.
## `wrack_level`: 0 = normal, 1 = wrack, 2 = Hyper-Wrack.
func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	pass
