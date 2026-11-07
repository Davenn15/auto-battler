class_name StunAttacksStatus
extends Status
## The unit's attacks briefly stun what they hit.

var duration: float


func _init(p_duration: float) -> void:
	duration = p_duration


## The stun's length is settled as the attack is made, so it can wrack (with an item that
## lets control effects wrack) even if Sumpton dies before a shot lands.
func get_hit_effect(unit: BattleUnit) -> HitEffect:
	return StunHitEffect.new(duration * unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL))
