class_name GritPassive
extends Passive
## Gives the unit Grit (see Grit): Amount percent of each hit it takes is spread over the
## next few seconds. Bescard's passive.

@export_range(1.0, 200.0, 1.0) var amount: float = 60.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GritGain.new(amount))


## Adds Grit for the rest of combat. Also used by the Grit Ascension.
class GritGain extends Status:
	var amount: float

	func _init(p_amount: float) -> void:
		amount = p_amount

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + amount if stat == Stats.Stat.GRIT else value
