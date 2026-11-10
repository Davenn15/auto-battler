class_name BarrageGambit
extends Gambit
## BAR.RAJ launches a barrage of missiles at the area with the most enemies. Each missile
## lands on a random point within Spread Cells of the area's centre and explodes, damaging
## every enemy within Blast Cells of where it lands.
## Damage per missile per enemy = Damage + Might Scaling x Might.
##   A: more missiles.  A1: tighter spread.

## How far away the area's centre can be, in hex cells.
@export var range_cells: int = 5
## How far from the centre missiles can land, in hex cells.
@export var spread_cells: int = 2
@export var missiles: int = 8
## Seconds between missiles.
@export var interval: float = 0.08
## Blast radius of each missile, in hex cells (0.8 = most of a cell).
@export var blast_cells: float = 0.8
@export var damage: float = 60.0
@export var might_scaling: float = 0.4
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var center = _best_center(caster)
	if center == null:
		return
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var blast := blast_cells * caster.grid.cell_spacing()
	for i in missiles:
		var point := random_point(caster.grid, center, spread_cells)
		var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		var amount := hit * caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
		fire(caster, point, blast, amount, damage_type, level, i * interval)
	caster.show_float_text("Barrage", BarrageMissile.COLOR)


## Launches one missile from `caster` to `point`.
static func fire(caster: BattleUnit, point: Vector2, blast: float, amount: float, type: int,
		level: int, delay: float) -> void:
	var missile := BarrageMissile.new()
	missile.setup(caster, caster.global_position, point, blast, amount, type, level, delay)
	caster.get_tree().current_scene.add_child(missile)
	missile.global_position = caster.global_position


## A random point on the board within `spread` cells of `center`: a random cell, nudged a
## little so missiles don't all land dead centre on a hex.
static func random_point(grid: BattleGrid, center: Vector2i, spread: int) -> Vector2:
	var cells: Array[Vector2i] = []
	for dq in range(-spread, spread + 1):
		for dr in range(-spread, spread + 1):
			var cell := center + Vector2i(dq, dr)
			if grid.get_distance(center, cell) <= spread and grid.has_cell(cell):
				cells.append(cell)
	if cells.is_empty():
		cells.append(center)
	var cell: Vector2i = CombatRng.pick(cells)
	var nudge := Vector2.from_angle(CombatRng.randf() * TAU) * CombatRng.randf() * grid.cell_spacing() * 0.4
	return grid.cell_to_world(cell) + nudge


## The cell of the enemy in range with the most enemies within Spread Cells of it (ties go
## to the nearest), or null if no enemy is in range.
func _best_center(caster: BattleUnit):
	var enemies := _enemies_in_range(caster)
	enemies.sort_custom(func(a, b): return caster.grid.get_distance(caster.cell, a.cell) < caster.grid.get_distance(caster.cell, b.cell))
	var best = null
	var best_count := 0
	for enemy in enemies:
		var count := 0
		for other in enemies:
			if caster.grid.get_distance(enemy.cell, other.cell) <= spread_cells:
				count += 1
		if count > best_count:
			best_count = count
			best = enemy.cell
	return best


func _enemies_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result
