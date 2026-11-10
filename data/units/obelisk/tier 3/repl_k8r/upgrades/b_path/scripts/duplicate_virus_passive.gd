class_name DuplicateVirusPassive
extends Passive
## REPL\K8R B1: its duplicates' attacks apply Mono-Virus.

@export var stacks: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VirusStrikeStatus.new(stacks))


class VirusStrikeStatus extends Status:
	var stacks: int

	func _init(p_stacks: int) -> void:
		stacks = p_stacks

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if unit.is_summon:   # duplicates only, not the original
			MonoVirusStatus.infect(target, stacks, unit.get_credit_id())
