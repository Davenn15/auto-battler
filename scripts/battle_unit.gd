class_name BattleUnit
extends Node2D
## Grid-based auto battler unit. Scene structure: a Node2D root with this script
## plus whatever visuals you like (Sprite2D etc.). No physics body or NavigationAgent.

signal died(unit: BattleUnit)

@export var team: int = 0
@export var max_health: float = 100.0
@export var damage: float = 10.0
@export var move_speed: float = 120.0     # pixels/sec while sliding between cells
@export var attack_range: int = 1         # measured in hex cells
@export var attack_cooldown: float = 1.0
@export var retarget_interval: float = 0.5

var data: UnitData            # assigned by whatever spawns the unit (e.g. the prep controller)
var auto_place: bool = true   # snap to the nearest cell in _ready(); spawners turn this off

var health: float
var cell: Vector2i            # the cell this unit is logically standing in
var target: BattleUnit = null
var active: bool = false      # set true when the combat phase starts
var alive: bool = true

var grid: BattleGrid
var _moving: bool = false
var _dest_cell: Vector2i
var _dest_world: Vector2
var _attack_timer: float = 0.0
var _retarget_timer: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group("units")

	grid = get_tree().get_first_node_in_group("battle_grid") as BattleGrid
	if grid == null:
		push_error("BattleUnit needs a BattleGrid in the scene.")
		return

	# Units placed by hand in the editor snap to the nearest cell. Units created by
	# a spawner set auto_place = false and call place_at() themselves.
	if auto_place:
		var start_cell := grid.world_to_cell(global_position)
		if not grid.has_cell(start_cell):
			push_error("%s is placed outside the grid." % name)
			return
		if grid.is_occupied(start_cell):
			push_warning("%s shares a cell with another unit." % name)
		place_at(start_cell)


## Moves the unit onto `new_cell`, keeping position, `cell`, and grid occupancy in sync.
func place_at(new_cell: Vector2i) -> void:
	grid.vacate(cell, self)   # no-op if we weren't holding that cell
	cell = new_cell
	global_position = grid.cell_to_world(new_cell)
	grid.occupy(new_cell, self)


func start_combat() -> void:
	active = true


func stop_combat() -> void:
	active = false   # a step already in progress still finishes, so units stay on-grid


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_retarget_timer -= delta

	# Finish any step in progress before making a new decision.
	if _moving:
		_continue_step(delta)
		return

	if not active:
		return

	if not _is_valid_target(target):
		target = null
	if target == null or _retarget_timer <= 0.0:
		_retarget_timer = retarget_interval
		target = _find_nearest_enemy()
	if target == null:
		return

	if grid.get_distance(cell, target.cell) <= attack_range:
		if _attack_timer <= 0.0:
			_attack(target)
	else:
		_start_step()


func _start_step() -> void:
	var next := grid.get_next_step(cell, target.cell)
	if next == cell:
		return   # no free path right now; try again next frame
	_dest_cell = next
	_dest_world = grid.cell_to_world(next)
	grid.occupy(next, self)   # reserve the destination immediately
	_moving = true


func _continue_step(delta: float) -> void:
	global_position = global_position.move_toward(_dest_world, move_speed * delta)
	if global_position.is_equal_approx(_dest_world):
		grid.vacate(cell, self)   # release the old cell only once we've arrived
		cell = _dest_cell
		_moving = false


func _find_nearest_enemy() -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u == null or not _is_valid_target(u):
			continue
		var d := grid.get_distance(cell, u.cell)
		if d < best_dist:
			best_dist = d
			best = u
	return best


func _is_valid_target(u) -> bool:
	return is_instance_valid(u) and u.alive and u.team != team


func _attack(enemy: BattleUnit) -> void:
	_attack_timer = attack_cooldown
	enemy.take_damage(damage)


func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	print("%s health: %.1f / %.1f" % [name, maxf(health, 0.0), max_health])
	if health <= 0.0:
		_die()


func _die() -> void:
	alive = false
	remove_from_group("units")
	grid.vacate(cell, self)
	if _moving:
		grid.vacate(_dest_cell, self)
	died.emit(self)
	queue_free()
