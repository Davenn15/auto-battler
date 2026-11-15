class_name SapOnHitEffect
extends Passive
## Hit Effect: Saps some of a stat from the target.

@export var stat: Stats.Stat = Stats.Stat.INSIGHT
@export var amount: float = 1.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Leech.new(self))


class Leech extends Status:
	var effect: SapOnHitEffect

	func _init(p_effect: SapOnHitEffect) -> void:
		effect = p_effect

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return SapHit.new(unit, effect)


class SapHit extends HitEffect:
	var attacker   # untyped: may be freed before a shot lands
	var effect: SapOnHitEffect

	func _init(p_attacker: BattleUnit, p_effect: SapOnHitEffect) -> void:
		attacker = p_attacker
		effect = p_effect

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not target.alive or not is_instance_valid(attacker):
			return   # the Sapped stat goes to the attacker, so it needs one
		# An item can let debuffs wrack, Sapping more.
		var amount: float = effect.amount * attacker.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
		Sap.stat(attacker, target, effect.stat, amount)
