class_name SapOnHitEffect
extends Passive
## Each attack that lands Saps some of a stat from the target.

@export var stat: Stats.Stat = Stats.Stat.INSIGHT
@export var amount: float = 1.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Leech.new(self))


class Leech extends Status:
	var effect: SapOnHitEffect

	func _init(p_effect: SapOnHitEffect) -> void:
		effect = p_effect

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if target.alive:
			# An item can let debuffs wrack, Sapping more.
			var amount := effect.amount * unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
			Sap.stat(unit, target, effect.stat, amount)
