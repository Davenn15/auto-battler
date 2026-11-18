class_name GambitTargetStatEffect
extends Passive
## An Ascension effect (Rallying Cry): every unit the unit's Gambit affects gains a stat
## for the rest of combat, stacking with each cast. See BattleUnit.gambit_affected.

@export var stat: Stats.Stat = Stats.Stat.CELERITY
@export var amount: float = 5.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GiverStatus.new(self))


class GiverStatus extends Status:
	var effect: GambitTargetStatEffect

	func _init(p_effect: GambitTargetStatEffect) -> void:
		effect = p_effect

	func on_gambit_target(unit: BattleUnit, target: BattleUnit) -> void:
		var stack: StackStatus = null
		for status in target.statuses:
			if status is StackStatus and status.source_id == unit.get_instance_id() and status.stat == effect.stat:
				stack = status
				break
		if stack == null:
			stack = StackStatus.new(unit.get_instance_id(), effect.stat)
			target.add_status(stack)
		stack.total += effect.amount
		target.gain_permanent_stats({effect.stat: effect.amount})
		target.show_float_text("+%d %s" % [roundi(effect.amount), Stats.STAT_NAMES[effect.stat]], Color(1.0, 0.85, 0.35))


## The stat a unit has gained from one caster's Gambits so far.
class StackStatus extends Status:
	var source_id: int
	var stat: Stats.Stat
	var total := 0.0

	func _init(p_source_id: int, p_stat: Stats.Stat) -> void:
		source_id = p_source_id
		stat = p_stat

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		return value + total if which == stat else value

	## It lasts all combat, so it never blocks Charge, even on the caster itself (Lunck's
	## Gambit affects him too; a status gained from your own Gambit otherwise would, forever).
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
