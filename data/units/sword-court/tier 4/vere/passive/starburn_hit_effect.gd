class_name StarburnHitEffect
extends HitEffect
## Leaves a ramping burn worth a share of what the attack dealt. A dodged attack leaves
## none, and a wracking attack leaves a bigger one, since it dealt more.

var source_id: int
var share: float      # 0.4 = the burn deals 40% of the hit again
var duration: float
var ramp_time: float = 0.0     # see StarburnStatus
var burst_share: float = 0.0
var burst_radius: int = 1


func _init(p_source_id: int, p_share: float, p_duration: float) -> void:
	source_id = p_source_id
	share = p_share
	duration = p_duration


func apply(target: BattleUnit, dealt: float, _wrack_level: int) -> void:
	if target.alive:
		var burn := RampingBurnStatus.new(source_id, dealt * share, duration, ramp_time)
		burn.burst_share = burst_share
		burn.burst_radius = burst_radius
		target.add_status(burn)
