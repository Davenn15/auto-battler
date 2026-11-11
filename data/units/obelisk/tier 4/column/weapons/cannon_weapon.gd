class_name ColumnCannonWeapon
extends ColumnWeapon
## A1: fires an energy shell at the enemy with the most other enemies around it. It explodes
## on impact, damaging every enemy within Blast Radius of where it lands.
## Damage = Damage + Might Scaling x Might.

## How far the shell can reach, in hex cells.
@export var range_cells: int = 6
@export var blast_radius_cells: int = 1
@export var damage: float = 90.0
@export var might_scaling: float = 0.6
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Seconds the shell takes to land.
@export var flight_time: float = 0.45


func fire(unit: BattleUnit) -> bool:
	var target := _best_target(unit)
	if target == null:
		return false
	var hit := Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	var level := unit.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= unit.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
	var shell := EnergyShell.new()
	shell.setup(unit, target.cell, hit, level, damage_type, blast_radius_cells, flight_time)
	unit.get_parent().add_child(shell)
	shell.global_position = unit.global_position
	return true


## The enemy in range with the most enemies within the blast of it (ties go to the nearest).
func _best_target(unit: BattleUnit) -> BattleUnit:
	var enemies := ColumnWeapon.enemies_in_range(unit, range_cells)   # nearest first
	var best: BattleUnit = null
	var best_count := 0
	for aim in enemies:
		var count := 0
		for other in enemies:
			if unit.grid.get_distance(aim.cell, other.cell) <= blast_radius_cells:
				count += 1
		if count > best_count:
			best_count = count
			best = aim
	return best


## The shell in flight: a glowing lime orb that arcs to its cell and explodes there.
class EnergyShell extends Node2D:
	var caster_id: int
	var team: int
	var grid: BattleGrid
	var cell: Vector2i
	var damage: float
	var wrack_level: int
	var damage_type: int
	var radius_cells: int
	var flight_time: float
	var _from: Vector2
	var _to: Vector2
	var _time := 0.0

	func setup(unit: BattleUnit, p_cell: Vector2i, p_damage: float, p_level: int, p_type: int,
			p_radius: int, p_flight: float) -> void:
		caster_id = unit.get_instance_id()
		team = unit.team
		grid = unit.grid
		cell = p_cell
		damage = p_damage
		wrack_level = p_level
		damage_type = p_type
		radius_cells = p_radius
		flight_time = maxf(p_flight, 0.05)
		_from = unit.global_position
		_to = unit.grid.cell_to_world(p_cell)
		z_index = 14

	func _physics_process(delta: float) -> void:
		_time += delta
		var t := minf(_time / flight_time, 1.0)
		global_position = _from.lerp(_to, t) + Vector2(0, -40.0 * sin(PI * t))   # a low arc
		if t >= 1.0:
			_explode()

	func _explode() -> void:
		set_physics_process(false)
		var caster := instance_from_id(caster_id) as BattleUnit
		for node in get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == team \
					or grid.get_distance(cell, enemy.cell) > radius_cells:
				continue
			var dealt := enemy.take_damage(damage, wrack_level, damage_type, false, caster)
			get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
		KeepsakeVfx.missile_blast(get_parent(), _to, (radius_cells + 0.5) * grid.cell_spacing(), ColumnWeapon.COLOR)
		queue_free()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pulse := 1.0 + 0.2 * sin(_time * 40.0)
		draw_circle(Vector2.ZERO, 9.0 * pulse, Color(ColumnWeapon.COLOR, 0.35))
		draw_circle(Vector2.ZERO, 5.5, ColumnWeapon.COLOR)
		draw_circle(Vector2.ZERO, 2.5, ColumnWeapon.LIGHT)
