class_name CrowdSpeedPassive
extends Passive
## Glaive gains Celerity for each enemy near it, counted continuously.

@export var celerity_per_enemy: float = 15.0
## Enemies within this many hexes count.
@export var range_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CrowdSpeedStatus.new(celerity_per_enemy, range_cells))


class CrowdSpeedStatus extends Status:
	var per_enemy: float
	var range_cells: int
	var _count := 0

	func _init(p_per_enemy: float, p_range: int) -> void:
		per_enemy = p_per_enemy
		range_cells = p_range

	func tick(unit: BattleUnit, _delta: float) -> void:
		_count = 0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other != null and other.alive and other.team != unit.team \
					and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
				_count += 1

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + per_enemy * _count if stat == Stats.Stat.CELERITY else value
