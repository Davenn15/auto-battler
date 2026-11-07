class_name StarburnHitEffect
extends HitEffect
## Leaves a ramping burn worth a share of what the attack dealt. A dodged attack leaves
## none, and a wracking attack leaves a bigger one, since it dealt more.

var source_id: int
var share: float      # 0.4 = the burn deals 40% of the hit again
var duration: float


func _init(p_source_id: int, p_share: float, p_duration: float) -> void:
	source_id = p_source_id
	share = p_share
	duration = p_duration


func apply(target: BattleUnit, dealt: float, _wrack_level: int) -> void:
	if target.alive:
		target.add_status(RampingBurnStatus.new(source_id, dealt * share, duration))
