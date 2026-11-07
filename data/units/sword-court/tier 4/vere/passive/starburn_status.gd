class_name StarburnStatus
extends Status
## The unit's attacks leave a ramping burn on what they hit.

var share: float
var duration: float


func _init(p_share: float, p_duration: float) -> void:
	share = p_share
	duration = p_duration


func get_hit_effect(unit: BattleUnit) -> HitEffect:
	return StarburnHitEffect.new(unit.get_credit_id(), share, duration)
