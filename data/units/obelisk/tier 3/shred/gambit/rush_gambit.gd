class_name ShredRushGambit
extends Gambit
## SHRED: dashes to a free cell next to the enemy with the highest Celerity (ties go to the
## nearest, then the lower instance id), locks onto it for Duration seconds, and gains
## Penetration flat Ward penetration for Duration seconds: its hits treat the target's Ward
## as that much lower, never below 0. Casting again starts both over.

@export var penetration: float = 20.0
@export var duration: float = 4.0

const DASH_TIME := 0.3


func can_use(caster: BattleUnit) -> bool:
	return _fastest_enemy(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var enemy := _fastest_enemy(caster)
	if enemy == null:
		return
	var dest := adjacent_cell(caster, enemy)
	if dest != caster.cell:
		var from := caster.global_position
		caster.lock_for(DASH_TIME)
		caster.force_move(dest, DASH_TIME)
		ShredFx.dash_streak(caster, from, caster.grid.cell_to_world(dest))
	caster.target = enemy
	for status in caster.statuses:
		if status is RushStatus:
			status.refresh(self, enemy)
			return
	caster.add_status(RushStatus.new(self, enemy))
	caster.show_float_text("Shredding", ShredFx.LIGHT)


## The living, targetable enemy with the most Celerity.
func _fastest_enemy(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if best == null:
			best = unit
			continue
		var cel := unit.get_stat(Stats.Stat.CELERITY)
		var best_cel := best.get_stat(Stats.Stat.CELERITY)
		if cel > best_cel:
			best = unit
		elif is_equal_approx(cel, best_cel):
			var da := caster.grid.get_distance(caster.cell, unit.cell)
			var db := caster.grid.get_distance(caster.cell, best.cell)
			if da < db or (da == db and unit.get_instance_id() < best.get_instance_id()):
				best = unit
	return best


## Its own cell if it's already next to `enemy`, else the free cell next to it nearest
## SHRED (staying put if there's none).
static func adjacent_cell(caster: BattleUnit, enemy: BattleUnit) -> Vector2i:
	var grid := caster.grid
	if grid.get_distance(caster.cell, enemy.cell) <= 1:
		return caster.cell
	var best := caster.cell
	var best_d := INF
	for cell in grid.free_cells_in_range(enemy.cell, 1):
		var d := grid.cell_to_world(cell).distance_to(caster.global_position)
		if d < best_d:
			best_d = d
			best = cell
	return best


## The penetration and the lock-on.
class RushStatus extends Status:
	var penetration: float
	var time_left: float
	var locked   # untyped: may be freed

	func _init(p_gambit: ShredRushGambit, p_enemy: BattleUnit) -> void:
		refresh(p_gambit, p_enemy)

	func refresh(p_gambit: ShredRushGambit, p_enemy: BattleUnit) -> void:
		penetration = p_gambit.penetration
		time_left = p_gambit.duration
		locked = p_enemy

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_target_ward(_unit: BattleUnit, _target: BattleUnit, ward: float, _wrack_level: int) -> float:
		if ward <= 0.0:
			return ward
		return maxf(ward - penetration, 0.0)

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
			return
		if is_instance_valid(locked) and locked.alive and locked.is_targetable():
			unit.target = locked   # stays on it for the duration
		else:
			locked = null
