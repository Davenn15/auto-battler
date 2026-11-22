class_name ShredFixationPassive
extends Passive
## SHRED A: each of its attacks that hits the same target as the last one adds a stack of
## +Celerity Per Stack Celerity, up to Max Stacks. Hitting a different target starts over
## at one stack.

@export var celerity_per_stack: float = 5.0
@export var max_stacks: int = 15


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(FixationStatus.new(self))


class FixationStatus extends Status:
	var passive: ShredFixationPassive
	var stacks := 0
	var last_target   # untyped: may be freed

	func _init(p_passive: ShredFixationPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_attack_hit(_unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if is_instance_valid(last_target) and target == last_target:
			stacks = mini(stacks + 1, passive.max_stacks)
		else:
			last_target = target
			stacks = 1

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.CELERITY:
			return value + passive.celerity_per_stack * stacks
		return value
