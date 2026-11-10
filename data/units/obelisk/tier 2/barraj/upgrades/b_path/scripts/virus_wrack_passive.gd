class_name VirusWrackPassive
extends Passive
## BAR.RAJ B2: his attacks get extra wrack chance against enemies carrying Mono-Virus.

## Wrack chance added (0.25 = +25%).
@export var bonus_chance: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VirusWrackStatus.new(bonus_chance))


class VirusWrackStatus extends Status:
	var bonus: float

	func _init(p_bonus: float) -> void:
		bonus = p_bonus

	func modify_wrack_chance(_unit: BattleUnit, target: BattleUnit, chance: float) -> float:
		return chance + bonus if MonoVirusStatus.stacks_on(target) > 0 else chance
