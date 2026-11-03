class_name TectonicGambit
extends Gambit
## Takes a ranged stance for a while: extra attack range, and attacks become waves that
## hit every enemy in a line. Then dashes away from the current target, as far as it can
## while keeping that target in range.

@export var duration: float = 6.0
@export var range_bonus: int = 3
## How wide the waves are, in hex cells.
@export var wave_width_cells: float = 1.0
## How far the dash can go, in hex cells. 0 = no dash.
@export var dash_cells: int = 3
@export var dash_time: float = 0.2
## Shield Geomond gains every time he attacks during the stance.
@export var attack_shield: float = 80.0
@export var attack_shield_duration: float = 2.5
## Waves also give that shield to every ally they pass through.
@export var wave_shields_allies: bool = false
## Wards each wave hit removes for the rest of combat, up to Ward Shred Max in total. 0 = none.
@export var ward_shred_per_hit: float = 0.0
@export var ward_shred_max: float = 40.0
## Extra wave damage as a fraction of each enemy's max health (0.04 = 4%), on top of the
## passive's max-health damage.
@export_range(0.0, 0.2, 0.005) var wave_max_health_percent: float = 0.04

func can_use(caster: BattleUnit) -> bool:
	return _alive(caster.target)


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var target = caster.target   # untyped: it may be freed while we wait
	# Recasting refreshes the stance instead of stacking a second one.
	for status in caster.statuses.duplicate():
		if status is TectonicStatus:
			caster.remove_status(status)
	var stance := TectonicStatus.new(duration, range_bonus, wave_width_cells * caster.grid.cell_spacing() * 0.5)
	stance.attack_shield = attack_shield
	stance.attack_shield_duration = attack_shield_duration
	stance.wave_shields_allies = wave_shields_allies
	stance.ward_shred_per_hit = ward_shred_per_hit
	stance.ward_shred_max = ward_shred_max
	stance.wave_max_health_percent = wave_max_health_percent
	caster.add_status(stance)   # the range bonus is on before picking where to dash
	if _alive(target) and dash_cells > 0:
		caster.lock_for(dash_time)
		await caster.dash_to(_retreat_cell(caster, target), dash_time)


## Where to dash: his own cell or a free cell in dash range, keeping `target` in attack
## range. Prefers cells with more allies between it and the target, so his waves pass
## through them; then cells farther from the target; then the nearest cell.
func _retreat_cell(caster: BattleUnit, target: BattleUnit) -> Vector2i:
	var grid := caster.grid
	var allies := _allies(caster)
	var half_width := wave_width_cells * grid.cell_spacing() * 0.5
	var best := caster.cell
	var best_score := _retreat_score(caster, caster.cell, target, allies, half_width)
	var cells := grid.free_cells_in_range(caster.cell, dash_cells)
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	for cell in cells:
		if grid.get_distance(cell, target.cell) > caster.attack_range:
			continue   # too far to keep hitting the target
		var score := _retreat_score(caster, cell, target, allies, half_width)
		if score > best_score:
			best_score = score
			best = cell
	return best


## Each ally a wave from `cell` to the target would pass through is worth more than any
## amount of distance; distance from the target breaks ties.
func _retreat_score(caster: BattleUnit, cell: Vector2i, target: BattleUnit, allies: Array[BattleUnit], half_width: float) -> int:
	var origin := caster.grid.cell_to_world(cell)
	var to_target := target.global_position - origin
	var dir := to_target.normalized()
	var covered := 0
	for ally in allies:
		if SlamGambit.in_rectangle(ally.global_position, origin, dir, to_target.length(), half_width):
			covered += 1
	return covered * 100 + caster.grid.get_distance(cell, target.cell)


func _allies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit != caster and unit.alive and unit.team == caster.team:
			result.append(unit)
	return result


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
