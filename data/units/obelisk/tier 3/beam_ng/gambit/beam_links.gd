class_name BeamLinks
extends RefCounted
## The beams of a BEAM.NG Gambit drawn on screen as a chain: from BEAM.NG to its target,
## then from each target to the next one it ricochets to. Also the target picking its
## Gambits share.

var _caster   # untyped: may be freed
var _lines: Array = []   # BeamStatus.BeamLine, one per link


func _init(caster: BattleUnit) -> void:
	_caster = caster


## Draws BEAM.NG -> chain[0] -> chain[1] -> ...
func show(chain: Array, color: Color) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(_caster) or not _caster.is_inside_tree():
		return
	while _lines.size() < chain.size():
		var line := BeamStatus.BeamLine.new()
		line.z_index = 9
		_caster.get_tree().current_scene.add_child(line)
		_lines.append(line)
	for i in _lines.size():
		var line = _lines[i]
		if not is_instance_valid(line):
			continue
		line.visible = i < chain.size()
		if i < chain.size():
			line.owner_unit = _caster if i == 0 else chain[i - 1]
			line.target = chain[i]
			line.firing = true
			line.color = color


func clear() -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()


## The ally of `caster` (not `caster`) within `range_cells` of `from`, not in `skip`, with the
## lowest share of its health; ties go to the nearest. Null if none.
static func lowest_ally(caster: BattleUnit, from: BattleUnit, range_cells: int, skip: Array) -> BattleUnit:
	var best: BattleUnit = null
	var best_share := INF
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or not unit.active or unit.team != caster.team \
				or skip.has(unit):
			continue
		if caster.grid.get_distance(from.cell, unit.cell) > range_cells:
			continue
		var share := unit.health / maxf(unit.max_health, 1.0)
		if share < best_share - 0.0001 or (is_equal_approx(share, best_share) and best != null \
				and caster.grid.get_distance(from.cell, unit.cell) < caster.grid.get_distance(from.cell, best.cell)):
			best = unit
			best_share = share
	return best


## The nearest enemy of `caster` within `range_cells` of `from`, not in `skip`. Null if none.
static func nearest_enemy(caster: BattleUnit, from: BattleUnit, range_cells: int, skip: Array) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable() or skip.has(unit):
			continue
		var distance := caster.grid.get_distance(from.cell, unit.cell)
		if distance <= range_cells and (best == null or distance < caster.grid.get_distance(from.cell, best.cell)):
			best = unit
	return best
