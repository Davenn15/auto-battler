class_name StunAttacksStatus
extends Status
## The unit's attacks briefly stun what they hit.

var duration: float


func _init(p_duration: float) -> void:
	duration = p_duration


func get_hit_effect(_unit: BattleUnit) -> HitEffect:
	return StunHitEffect.new(duration)
