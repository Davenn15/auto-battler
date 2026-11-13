class_name ColumnWeapon
extends Passive
## One of COLUMN's weapons. Each weapon is a passive with its own attack timer, so an
## upgrade adds a weapon by adding its passive. The timer runs at Interval seconds at
## normal attack speed, and faster or slower with COLUMN's Celerity, the same way normal
## attacks do. Weapons rest while COLUMN is stunned or Phased.
## Subclasses override fire(); continuous weapons (beams) override make_status() instead.

const COLOR := Color(0.62, 1.0, 0.2)   # lime green
const LIGHT := Color(0.85, 1.0, 0.6)

## Seconds between shots at normal attack speed (100 Celerity).
@export var interval: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(make_status())


func make_status() -> Status:
	return TimerStatus.new(self)


## Fires once. Return false if there was nothing to fire at; it tries again shortly.
func fire(_unit: BattleUnit) -> bool:
	return false


## How much COLUMN's attack speed stretches or shrinks a timer (0.5 = twice as fast).
static func speed_scale(unit: BattleUnit) -> float:
	return unit.get_attack_cooldown() / Stats.BASE_ATTACK_COOLDOWN


## True while COLUMN can use its weapons: in combat, alive, not stunned or Phased.
static func can_act(unit: BattleUnit) -> bool:
	return unit.active and unit.alive and unit._stunned_time <= 0.0 and not PhaseStatus.is_phased(unit)


## Living, targetable enemies within `range_cells` of COLUMN, nearest first.
static func enemies_in_range(unit: BattleUnit, range_cells: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other.alive and other.team != unit.team and other.is_targetable() \
				and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
			result.append(other)
	result.sort_custom(func(a, b): return unit.grid.get_distance(unit.cell, a.cell) < unit.grid.get_distance(unit.cell, b.cell))
	return result


## The living ally (not COLUMN, not out of combat) with the lowest share of its max health
## within `range_cells`, or null. With `hurt_only`, only allies below full health.
static func lowest_ally(unit: BattleUnit, range_cells: int, hurt_only: bool) -> BattleUnit:
	var best: BattleUnit = null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other == null or other == unit or not other.alive or not other.active or other.team != unit.team:
			continue
		if unit.grid.get_distance(unit.cell, other.cell) > range_cells:
			continue
		var share := other.health / maxf(other.max_health, 1.0)
		if hurt_only and share >= 0.999:
			continue
		if best == null or share < best.health / maxf(best.max_health, 1.0):
			best = other
	return best


## For weapons that fire in a straight line (A1's wave, B2's laser): the direction, in the
## world (as from cell_to_world), of the line from COLUMN that hits the most enemies within `length_cells`
## (aimed at each enemy in reach in turn). Vector2.ZERO if no enemy is in reach.
static func best_line(unit: BattleUnit, length_cells: int, width_cells: float = 1.1) -> Vector2:
	var best := Vector2.ZERO
	var most := 0
	for enemy in enemies_in_range(unit, length_cells):
		var dir := (unit.grid.cell_to_world(enemy.cell) - unit.grid.cell_to_world(unit.cell)).normalized()
		var count := enemies_on_line(unit, dir, length_cells, width_cells).size()
		if count > most:
			most = count
			best = dir
	return best


## Living, targetable enemies on the line from COLUMN along `dir` (world space, as from cell_to_world), up to
## `length_cells` long and `width_cells` wide (1.1 = a little over one cell).
static func enemies_on_line(unit: BattleUnit, dir: Vector2, length_cells: int, width_cells: float = 1.1) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	if dir == Vector2.ZERO:
		return result
	var start := unit.grid.cell_to_world(unit.cell)
	var spacing := unit.grid.cell_spacing()
	var reach := (length_cells + 0.5) * spacing
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other == null or not other.alive or other.team == unit.team or not other.is_targetable():
			continue
		if _on_line(start, unit.grid.cell_to_world(other.cell), dir, reach, spacing * width_cells * 0.5):
			result.append(other)
	return result


## Every cell the same line covers (the same test as enemies_on_line), to show its exact
## hit zone on the ground.
static func cells_on_line(unit: BattleUnit, dir: Vector2, length_cells: int, width_cells: float = 1.1) -> Array:
	var result := []
	if dir == Vector2.ZERO:
		return result
	var start := unit.grid.cell_to_world(unit.cell)
	var spacing := unit.grid.cell_spacing()
	var reach := (length_cells + 0.5) * spacing
	for cell in unit.grid.all_cells():
		if _on_line(start, unit.grid.cell_to_world(cell), dir, reach, spacing * width_cells * 0.5):
			result.append(cell)
	return result


## True if `point` is ahead of `start` along `dir`, no farther than `reach`, and within
## `half_width` of the line.
static func _on_line(start: Vector2, point: Vector2, dir: Vector2, reach: float, half_width: float) -> bool:
	var offset := point - start
	var along := offset.dot(dir)
	return along > 0.0 and along <= reach and absf(offset.cross(dir)) <= half_width


## Runs a weapon's timer.
class TimerStatus extends Status:
	const RETRY := 0.25   # seconds before trying again when there was nothing to fire at
	var weapon: ColumnWeapon
	var _left := 0.0

	func _init(p_weapon: ColumnWeapon) -> void:
		weapon = p_weapon
		_left = p_weapon.interval * 0.5   # the first shot comes half an interval in

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, delta: float) -> void:
		if not ColumnWeapon.can_act(unit):
			return
		_left -= delta
		if _left > 0.0:
			return
		_left = weapon.interval * ColumnWeapon.speed_scale(unit) if weapon.fire(unit) else RETRY
