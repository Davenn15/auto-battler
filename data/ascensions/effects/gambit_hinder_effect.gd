class_name GambitHinderEffect
extends Passive
## An Ascension effect (Enfeebling Hex): the unit's Gambit damage Hinders enemies (their
## Might, Insight and Celerity drop by Share for Duration seconds). Shots its Gambit made
## that fire on their own, like Trompero's Arcane Blades, Hinder too.

@export_range(0.0, 1.0, 0.01) var share: float = 0.2
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(HexStatus.new(self))


class HexStatus extends Status:
	var effect: GambitHinderEffect

	func _init(p_effect: GambitHinderEffect) -> void:
		effect = p_effect

	func on_gambit_damage(_unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		HinderStatus.hinder(target, effect.share, effect.duration)

	func get_gambit_shot_effect(_unit: BattleUnit) -> HitEffect:
		return HinderHit.new(effect.share, effect.duration)


class HinderHit extends HitEffect:
	var share: float
	var duration: float

	func _init(p_share: float, p_duration: float) -> void:
		share = p_share
		duration = p_duration

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		HinderStatus.hinder(target, share, duration)
