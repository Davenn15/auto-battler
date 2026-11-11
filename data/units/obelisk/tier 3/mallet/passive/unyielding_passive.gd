class_name UnyieldingPassive
extends Passive
## MALLET: debuffs and crowd control are less effective on it. Crowd control (stuns,
## sleep, taunts, Clamp) lasts shorter. Timed debuffs wear off sooner; debuffs that last
## all combat (Sapped stats, ward shred, Mono-Virus) are weaker.

## Share taken off crowd control's duration (0.35 = 35% shorter).
@export_range(0.0, 1.0, 0.05) var crowd_control_reduction: float = 0.35
## Share taken off debuffs (0.35 = 35% shorter or 35% weaker).
@export_range(0.0, 1.0, 0.05) var debuff_reduction: float = 0.35


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(UnyieldingStatus.new(self))


class UnyieldingStatus extends Status:
	var passive: UnyieldingPassive

	func _init(p_passive: UnyieldingPassive) -> void:
		passive = p_passive

	func modify_crowd_control(_unit: BattleUnit, multiplier: float) -> float:
		return multiplier * (1.0 - passive.crowd_control_reduction)

	func modify_debuff_strength(_unit: BattleUnit, multiplier: float) -> float:
		return multiplier * (1.0 - passive.debuff_reduction)
