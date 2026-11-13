class_name ColumnLaserWeapon
extends ColumnWeapon
## B2: fires a powerful laser along the straight line hitting the most enemies. For
## Duration seconds, every enemy in the beam (it stays pointed the same way) takes Damage Per
## Second + Insight Scaling x Insight, plus Share Per Second of its max health, each second, as
## Insight damage.

@export var length_cells: int = 6
## How wide the beam is, in cells (1.5 = a hex and a half).
@export var width_cells: float = 1.5
@export var duration: float = 2.5
## Flat damage per second to each enemy in the beam.
@export var damage_per_second: float = 50.0
## Extra damage per second for each point of COLUMN's Insight (0.3 = +30 per 100 Insight).
@export var insight_scaling: float = 0.3
## Share of each enemy's max health dealt per second, on top (0.06 = 6%).
@export_range(0.0, 1.0, 0.01) var share_per_second: float = 0.06


func fire(unit: BattleUnit) -> bool:
	var dir := ColumnWeapon.best_line(unit, length_cells, width_cells)
	if dir == Vector2.ZERO:
		return false
	unit.add_status(LaserStatus.new(self, dir))
	unit.show_float_text("Laser", ColumnWeapon.LIGHT)
	return true


class LaserStatus extends Status:
	const TICK := 0.1
	var weapon: ColumnLaserWeapon
	var dir: Vector2
	var _left: float
	var _tick := 0.0
	var _visual: LaserLine

	func _init(p_weapon: ColumnLaserWeapon, p_dir: Vector2) -> void:
		weapon = p_weapon
		dir = p_dir
		_left = p_weapon.duration

	var _zone: KeepsakeVfx.CellZone   # the exact cells it hits, highlighted on the ground
	var _from_cell := Vector2i(-999, -999)

	func on_applied(unit: BattleUnit) -> void:
		if KeepsakeVfx.enabled():
			_visual = LaserLine.new()
			_visual.reach = (weapon.length_cells + 0.5) * unit.grid.cell_spacing()
			_visual.width = weapon.width_cells * unit.grid.cell_spacing()
			_visual.z_index = 12
			unit.get_parent().add_child(_visual)
			_visual.global_rotation = dir.angle()
			_zone = KeepsakeVfx.CellZone.new()
			_zone.grid = unit.grid
			_zone.color = ColumnWeapon.COLOR
			_zone.z_index = -1   # on the ground, under the units
			unit.get_parent().add_child(_zone)
			_follow(unit)

	func on_removed(_unit: BattleUnit) -> void:
		for node in [_visual, _zone]:
			if is_instance_valid(node):
				node.queue_free()

	## Starts the beam, and its highlighted cells, from COLUMN's cell: the same place its
	## damage is measured from. Updated if COLUMN moves to a new cell.
	func _follow(unit: BattleUnit) -> void:
		if unit.cell == _from_cell:
			return
		_from_cell = unit.cell
		if is_instance_valid(_visual):
			_visual.global_position = unit.grid.cell_to_world(unit.cell)
		if is_instance_valid(_zone):
			_zone.cells = ColumnWeapon.cells_on_line(unit, dir, weapon.length_cells, weapon.width_cells)

	func tick(unit: BattleUnit, delta: float) -> void:
		_left -= delta
		_follow(unit)
		if _left <= 0.0 or not unit.active or not unit.alive:
			unit.remove_status(self)
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick += TICK
		for enemy in ColumnWeapon.enemies_on_line(unit, dir, weapon.length_cells, weapon.width_cells):
			var flat := Stats.scaled(weapon.damage_per_second, weapon.insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))
			var amount := (flat + enemy.max_health * weapon.share_per_second) * TICK
			var dealt := enemy.take_damage(amount, 0, Stats.DamageType.INSIGHT, false, unit, false)
			unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
			enemy.add_running_damage("laser_%d" % get_instance_id(), dealt, Stats.damage_color(Stats.DamageType.INSIGHT))


## The beam: a wide soft glow, a bright core and a white-hot centre line, all flickering,
## with bands of light running down it.
class LaserLine extends Node2D:
	var reach := 300.0
	var width := 80.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flicker := 0.85 + 0.15 * sin(_time * 40.0)
		var end := Vector2(reach, 0)
		draw_line(Vector2.ZERO, end, Color(ColumnWeapon.COLOR, 0.22 * flicker), width)
		draw_line(Vector2.ZERO, end, Color(ColumnWeapon.COLOR, 0.45 * flicker), width * 0.6)
		draw_line(Vector2.ZERO, end, Color(ColumnWeapon.LIGHT, 0.85 * flicker), width * 0.25)
		draw_line(Vector2.ZERO, end, Color(1, 1, 1, flicker), maxf(width * 0.07, 2.0))
		for band in 5:   # light running outward along the beam
			var x := fposmod(_time * 500.0 + band * reach / 5.0, reach)
			draw_line(Vector2(x, -width * 0.3), Vector2(x, width * 0.3), Color(1, 1, 1, 0.35 * flicker), 3.0)
		draw_circle(Vector2.ZERO, width * 0.35, Color(ColumnWeapon.LIGHT, 0.6 * flicker))   # muzzle
