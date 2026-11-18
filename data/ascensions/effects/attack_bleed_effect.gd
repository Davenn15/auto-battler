class_name AttackBleedEffect
extends Passive
## An Ascension effect (Open Wounds): the unit's attacks (Flurry strikes included) gain the
## Hit Effect: Bleed for Percent of the target's max health (see Bleed).

@export_range(0.0, 0.5, 0.005) var percent: float = 0.06


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BleedGiverStatus.new(self))


class BleedGiverStatus extends Status:
	var effect: AttackBleedEffect

	func _init(p_effect: AttackBleedEffect) -> void:
		effect = p_effect

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return Bleed.BleedHit.new(unit.get_credit_id(), 0.0, effect.percent)
