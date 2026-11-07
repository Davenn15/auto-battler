class_name AttackerDebuffEffect
extends Passive
## Whenever an enemy attacks the unit, hit or miss, that enemy loses some of a stat for a while.

@export var stat: Stats.Stat = Stats.Stat.CELERITY
@export var amount: float = 5.0
@export var duration: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Thorn.new(self))


class Thorn extends Status:
	var effect: AttackerDebuffEffect

	func _init(p_effect: AttackerDebuffEffect) -> void:
		effect = p_effect

	func on_attacked(unit: BattleUnit, attacker: BattleUnit, _dealt: float) -> void:
		if is_instance_valid(attacker) and attacker.alive:
			# An item can let control effects wrack, deepening the debuff.
			var amount := effect.amount * unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, attacker)
			attacker.add_status(TimedStatStatus.new(effect.stat, -amount, effect.duration))
			KeepsakeVfx.harness_mark(attacker, effect.duration)
