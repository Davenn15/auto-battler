class_name StarshredderEffect
extends Passive
## Starshredder: Hit Effect: the target's highest Ward drops by Amount (Wrack Amount when
## the attack Wracked) for Duration seconds. Stacks.

@export var amount: float = 5.0
@export var wrack_amount: float = 5.0
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Shredder.new(self))


class Shredder extends Status:
	var effect: StarshredderEffect

	func _init(p_effect: StarshredderEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return StarHit.new(unit, effect)


class StarHit extends HitEffect:
	var attacker   # untyped: may be freed before the hit lands
	var effect: StarshredderEffect

	func _init(p_attacker: BattleUnit, p_effect: StarshredderEffect) -> void:
		attacker = p_attacker
		effect = p_effect

	func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
		if not target.alive:
			return
		var source: BattleUnit = attacker if is_instance_valid(attacker) else null
		var amount := effect.wrack_amount if wrack_level > 0 else effect.amount
		if source != null:
			amount *= source.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
		WardShiftStatus.shred(source, target, WardShiftStatus.highest_ward(target), amount, effect.duration)
