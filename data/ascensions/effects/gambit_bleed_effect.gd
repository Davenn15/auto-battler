class_name GambitBleedEffect
extends Passive
## An Ascension effect (Trompero's hero Ascension): the unit's Gambit damage also inflicts
## Bleed for Share of the damage dealt. Shots its Gambit made that fire on their own, like
## Trompero's Arcane Blades, Bleed too.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitBleedStatus.new(self))


class GambitBleedStatus extends Status:
	var effect: GambitBleedEffect

	func _init(p_effect: GambitBleedEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		Bleed.apply(target, amount * effect.share, unit, false)   # worked out from damage dealt

	func get_gambit_shot_effect(unit: BattleUnit) -> HitEffect:
		return BleedOnHit.new(unit.get_instance_id(), effect.share)


## A Gambit shot (Arcane Blades): Bleed for Share of the damage it dealt.
class BleedOnHit extends HitEffect:
	var source_id: int
	var share: float

	func _init(p_source_id: int, p_share: float) -> void:
		source_id = p_source_id
		share = p_share

	func apply(target: BattleUnit, dealt: float, _wrack_level: int) -> void:
		if dealt > 0.0:
			Bleed.apply(target, dealt * share, source_id, false)
