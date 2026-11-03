class_name RallyAuraStatus
extends Status
## Gives every living ally within range a Celerity bonus while they stay in range.
## Each ally gets a RallyBuffStatus that is added and removed as they enter and leave.

var celerity: float
var insight: float = 0.0
var range_cells: int
var include_self: bool
var _buffs: Dictionary = {}   # ally instance id -> RallyBuffStatus


func _init(p_celerity: float, p_range_cells: int, p_include_self: bool) -> void:
	celerity = p_celerity
	range_cells = p_range_cells
	include_self = p_include_self


func tick(unit: BattleUnit, _delta: float) -> void:
	var in_range := {}
	for ally in get_allies_in_range(unit, range_cells, include_self):
		var id := ally.get_instance_id()
		in_range[id] = true
		if not _buffs.has(id):
			var buff := RallyBuffStatus.new(unit.get_instance_id(), celerity, insight)
			_buffs[id] = buff
			ally.add_status(buff)

	for id in _buffs.keys():
		if in_range.has(id):
			continue
		var ally := instance_from_id(id) as BattleUnit   # null if it was freed
		if ally != null:
			ally.remove_status(_buffs[id])
		_buffs.erase(id)


func on_removed(_unit: BattleUnit) -> void:
	for id in _buffs:
		var ally := instance_from_id(id) as BattleUnit
		if ally != null:
			ally.remove_status(_buffs[id])
	_buffs.clear()


## Living allies within `cells` hex cells of `unit`. Shared with the Rally gambit.
static func get_allies_in_range(unit: BattleUnit, cells: int, with_self: bool) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other == null or not other.alive or other.team != unit.team:
			continue
		if other == unit and not with_self:
			continue
		if unit.grid.get_distance(unit.cell, other.cell) <= cells:
			result.append(other)
	return result
