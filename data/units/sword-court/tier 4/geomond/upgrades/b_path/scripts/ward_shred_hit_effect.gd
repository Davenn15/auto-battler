class_name WardShredHitEffect
extends HitEffect
## Lowers the target's wards for the rest of combat when the attack lands.

var per_hit: float
var cap: float


func _init(p_per_hit: float, p_cap: float) -> void:
	per_hit = p_per_hit
	cap = p_cap


func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	if not target.alive:
		return
	for status in target.statuses:
		if status is WardShredStatus:
			status.add(per_hit, cap)
			return
	var shred := WardShredStatus.new()
	shred.add(per_hit, cap)
	target.add_status(shred)
