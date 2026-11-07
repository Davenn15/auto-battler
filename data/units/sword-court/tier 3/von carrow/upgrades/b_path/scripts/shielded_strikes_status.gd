class_name ShieldedStrikesStatus
extends Status
## While the unit has any shield, its attacks deal extra damage equal to a share of the
## target's max health.

var percent: float


func _init(p_percent: float) -> void:
	percent = p_percent


func get_hit_effect(unit: BattleUnit) -> HitEffect:
	if unit.get_shield() <= 0.0:
		return null
	return MaxHealthHitEffect.new(unit.get_credit_id(), percent, unit.get_attack_damage_type(),
			1.0 + unit.get_stat(Stats.Stat.WRACK_DAMAGE))
