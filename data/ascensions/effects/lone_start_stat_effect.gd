class_name LoneStartStatEffect
extends Passive
## An Ascension effect (Knight Errant): a unit that starts combat with no allies in the
## cells next to it gains a stat for the whole combat.

@export var stat: Stats.Stat = Stats.Stat.CELERITY
@export var amount: float = 20.0


func on_battle_start(unit: BattleUnit) -> void:
	if not has_adjacent_ally(unit):
		unit.add_status(BonusStatus.new(stat, amount))


## True if a living ally of `unit` stands in a cell next to it.
static func has_adjacent_ally(unit: BattleUnit) -> bool:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.alive and other.team == unit.team \
				and unit.grid.get_distance(unit.cell, other.cell) == 1:
			return true
	return false


class BonusStatus extends Status:
	var stat: Stats.Stat
	var amount: float

	func _init(p_stat: Stats.Stat, p_amount: float) -> void:
		stat = p_stat
		amount = p_amount

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		return value + amount if which == stat else value
