class_name AttackBleedEffect
extends Passive
## An Ascension effect (Open Wounds): the unit's attacks gain the Hit Effect: the target
## bleeds for Percent of its max health per second for Duration seconds (bleeds stack).
## A Flurry Gambit that already leaves bleeds (Bescard's B2) makes them last Flurry Bonus
## seconds longer.

@export_range(0.0, 0.1, 0.0025) var percent: float = 0.03
@export var duration: float = 3.0
@export var flurry_bonus: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BleedGiverStatus.new(self))
	var flurry := unit.gambit as FlurryGambit
	if flurry != null and flurry.bleed_percent > 0.0 and flurry_bonus != 0.0:
		flurry = flurry.duplicate()   # this unit's own copy: never change the shared one
		flurry.bleed_duration += flurry_bonus
		unit.gambit = flurry


class BleedGiverStatus extends Status:
	var effect: AttackBleedEffect

	func _init(p_effect: AttackBleedEffect) -> void:
		effect = p_effect

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return BleedHitEffect.new(unit.get_credit_id(), effect.percent, effect.duration)
