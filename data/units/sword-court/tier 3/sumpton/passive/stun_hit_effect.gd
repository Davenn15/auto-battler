class_name StunHitEffect
extends HitEffect
## Stuns the target briefly when the attack lands. A dodged attack stuns no one.

var duration: float


func _init(p_duration: float) -> void:
	duration = p_duration


func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	if target.alive:
		target.stun(duration)
