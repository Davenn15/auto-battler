class_name StarburnStatus
extends Status
## The unit's attacks leave a ramping burn on what they hit.

var share: float
var duration: float
## The ramp the burn follows, in seconds: a burn worth X ramps up to dealing X over this
## long. A longer Duration keeps ramping past it, dealing more (Supernova). 0 = Duration.
var ramp_time: float = 0.0
## Supernova: when a burn runs its full length it bursts, dealing this share of each
## nearby enemy's max health as Insight damage, within Burst Radius cells. 0 = no burst.
var burst_share: float = 0.0
var burst_radius: int = 1


func _init(p_share: float, p_duration: float) -> void:
	share = p_share
	duration = p_duration


func get_hit_effect(unit: BattleUnit) -> HitEffect:
	var effect := StarburnHitEffect.new(unit.get_credit_id(), share, duration)
	effect.ramp_time = ramp_time
	effect.burst_share = burst_share
	effect.burst_radius = burst_radius
	return effect
