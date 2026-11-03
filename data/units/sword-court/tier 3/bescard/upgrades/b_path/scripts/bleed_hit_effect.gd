class_name BleedHitEffect
extends HitEffect
## Leaves a bleed on the target when the attack lands: a share of its max health per
## second, for a while. A dodged attack leaves none.

var source_id: int
var percent: float     # share of the target's max health per second (0.01 = 1%)
var duration: float


func _init(p_source_id: int, p_percent: float, p_duration: float) -> void:
	source_id = p_source_id
	percent = p_percent
	duration = p_duration


func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	if target.alive:   # the hit may have killed it
		target.add_status(BleedStatus.new(source_id, percent * target.max_health, duration))
