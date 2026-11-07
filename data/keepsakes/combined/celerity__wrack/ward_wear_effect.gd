class_name WardWearEffect
extends Passive
## Each attack that lands lowers all of the target's wards for the rest of combat.

@export var per_hit: float = 2.0
## Most it can lower one target's wards in total. 0 = no limit.
@export var cap: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Wear.new(self))


class Wear extends Status:
	var effect: WardWearEffect

	func _init(p_effect: WardWearEffect) -> void:
		effect = p_effect

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if not target.alive:
			return
		var limit := effect.cap if effect.cap > 0.0 else INF
		# An item can let control effects wrack, shredding more.
		var amount := effect.per_hit * unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
		KeepsakeVfx.shred(target)
		for status in target.statuses:
			if status is WardShredStatus:
				status.add(amount, limit)
				return
		var shred := WardShredStatus.new()
		shred.add(amount, limit)
		target.add_status(shred)
