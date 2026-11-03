class_name BladeBuffStatus
extends Status
## One of Sumpton's blades: a bonus to an attribute and its matching ward for the rest
## of combat. Several blades on one unit stack.

var attribute: Stats.Stat
var ward: Stats.Stat
var attribute_bonus: float
var ward_bonus: float


func _init(p_attribute: Stats.Stat, p_ward: Stats.Stat, p_attribute_bonus: float, p_ward_bonus: float) -> void:
	attribute = p_attribute
	ward = p_ward
	attribute_bonus = p_attribute_bonus
	ward_bonus = p_ward_bonus


## Statuses a Gambit creates block charge until they end. Blades never end, so they mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == attribute:
		return value + attribute_bonus
	if stat == ward:
		return value + ward_bonus
	return value
