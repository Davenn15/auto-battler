class_name FlatReductionEffect
extends Passive
## Each hit of Might damage the unit takes is reduced by a flat amount, and the same for
## Celerity damage. Damage over time isn't affected.

@export var might_reduction: float = 15.0
@export var celerity_reduction: float = 10.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Plating.new(self))


class Plating extends Status:
	var effect: FlatReductionEffect

	func _init(p_effect: FlatReductionEffect) -> void:
		effect = p_effect

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		if not unit.incoming_is_hit:
			return damage
		match unit.incoming_damage_type:
			Stats.DamageType.MIGHT:
				return maxf(damage - effect.might_reduction, 0.0)
			Stats.DamageType.CELERITY:
				return maxf(damage - effect.celerity_reduction, 0.0)
		return damage
