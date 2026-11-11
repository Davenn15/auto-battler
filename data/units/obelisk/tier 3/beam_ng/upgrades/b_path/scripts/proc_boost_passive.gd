class_name ProcBoostPassive
extends Passive
## BEAM.NG B: its continuous beams trigger once-per-attack effects (items, on-hit effects)
## more often. Bonus 0.3 = 30% more often. Several add up.

@export var bonus: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ProcBoostStatus.new(bonus))


class ProcBoostStatus extends Status:
	var bonus: float

	func _init(p_bonus: float) -> void:
		bonus = p_bonus

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
