class_name WrackBleedEffect
extends Passive
## An Ascension effect: whenever one of the unit's hits Wracks (attacks and Gambit damage),
## it also inflicts Bleed for Share of the damage that hit dealt.

@export_range(0.0, 2.0, 0.05) var share: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(WrackBleedStatus.new(self))


class WrackBleedStatus extends Status:
	var effect: WrackBleedEffect

	func _init(p_effect: WrackBleedEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## Attacks: settled as the attack is made; Bleeds only if it lands and Wracks.
	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return WrackBleedHit.new(unit.get_instance_id(), effect.share)

	## Gambit damage: the hit that was just dealt (BattleUnit.gambit_damage_dealt runs right
	## after it), so the target still knows whether it Wracked.
	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		if is_instance_valid(target) and target.incoming_wrack_level > 0:
			Bleed.apply(target, amount * effect.share, unit, false)


class WrackBleedHit extends HitEffect:
	var source_id: int
	var share: float

	func _init(p_source_id: int, p_share: float) -> void:
		source_id = p_source_id
		share = p_share

	func apply(target: BattleUnit, dealt: float, wrack_level: int) -> void:
		if wrack_level > 0 and dealt > 0.0:
			Bleed.apply(target, dealt * share, source_id, false)   # worked out from damage dealt
