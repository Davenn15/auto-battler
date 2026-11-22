class_name ShredBackstepGambit
extends Gambit
## SHRED B: dashes out to its maximum attack range from its target, to the free cell there
## with the most room from other enemies (ties go to the nearest one to SHRED), then gains
## Celerity and Ward Shred for Duration seconds: its hits ignore Ward Shred of the target's
## Wards. Casting again starts it over.
##   B2 (Untargetable Time): untargetable for that many seconds after casting.
## Its target is its current one, or the nearest enemy if it has none.

@export var celerity: float = 30.0
@export_range(0.0, 1.0, 0.05) var ward_shred: float = 0.4
@export var duration: float = 4.0
## B2: seconds untargetable after casting. 0 = none.
@export var untargetable_time: float = 0.0

const DASH_TIME := 0.3


func can_use(caster: BattleUnit) -> bool:
	return _target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _target(caster)
	if target == null:
		return
	if untargetable_time > 0.0:
		caster.add_status(UntargetableStatus.new(untargetable_time))
	var dest := _dash_cell(caster, target)
	if dest != caster.cell:
		var from := caster.global_position
		caster.lock_for(DASH_TIME)
		caster.force_move(dest, DASH_TIME)
		ShredFx.dash_streak(caster, from, caster.grid.cell_to_world(dest))
	caster.target = target
	for status in caster.statuses:
		if status is BackstepStatus:
			status.time_left = duration
			return
	caster.add_status(BackstepStatus.new(self))
	caster.show_float_text("Shred", ShredFx.LIGHT)


func _target(caster: BattleUnit) -> BattleUnit:
	var target := caster.target
	if is_instance_valid(target) and target.alive and target.is_targetable() and target.team != caster.team:
		return target
	var best: BattleUnit = null
	var best_d := 1 << 30
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		var d := caster.grid.get_distance(caster.cell, unit.cell)
		if d < best_d or (d == best_d and unit.get_instance_id() < best.get_instance_id()):
			best = unit
			best_d = d
	return best


## The free cell exactly its attack range from `target` with the most room from the other
## enemies (the distance to the nearest of them); ties go to the cell nearest SHRED, then the
## first found. Its own cell counts when it's at that range already. Stays put if there's none.
func _dash_cell(caster: BattleUnit, target: BattleUnit) -> Vector2i:
	var grid := caster.grid
	var reach := caster.attack_range
	var others: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit != target:
			others.append(unit)
	var best := caster.cell
	var best_room := -1
	var best_near := 1 << 30
	for cell in grid.all_cells():
		if grid.get_distance(cell, target.cell) != reach:
			continue
		if cell != caster.cell and not grid.can_place(cell):
			continue
		var room := 1 << 20
		for other in others:
			room = mini(room, grid.get_distance(cell, other.cell))
		var near := grid.get_distance(cell, caster.cell)
		if room > best_room or (room == best_room and near < best_near):
			best = cell
			best_room = room
			best_near = near
	return best


## Celerity and Ward Shred for a while.
class BackstepStatus extends Status:
	var gambit: ShredBackstepGambit
	var time_left: float

	func _init(p_gambit: ShredBackstepGambit) -> void:
		gambit = p_gambit
		time_left = p_gambit.duration

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + gambit.celerity if stat == Stats.Stat.CELERITY else value

	func modify_target_ward(_unit: BattleUnit, _target: BattleUnit, ward: float, _wrack_level: int) -> float:
		return ward * (1.0 - gambit.ward_shred) if ward > 0.0 else ward

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
