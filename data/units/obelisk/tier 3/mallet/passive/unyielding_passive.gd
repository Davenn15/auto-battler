class_name UnyieldingPassive
extends Passive
## MALLET: Immovability (see Stats.Stat.IMMOVABILITY): crowd control and debuffs on it last
## that much shorter.

@export var immovability: float = 40.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(UnyieldingStatus.new(self))


class UnyieldingStatus extends Status:
	var passive: UnyieldingPassive

	func _init(p_passive: UnyieldingPassive) -> void:
		passive = p_passive

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + passive.immovability if stat == Stats.Stat.IMMOVABILITY else value
